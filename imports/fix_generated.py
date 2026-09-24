#!/usr/bin/env python3
"""
imports/fix_generated.py <path/to/generated_legacy.tf> [--profile P]

Cleans the known `terraform plan -generate-config-out` defects so that
`terraform validate` passes. Stdlib only (runs on stock macOS python3).
Nothing here changes real infrastructure: every fix either removes a
zero/empty placeholder the provider rejects, or pins a value + ignore_changes
so the first plan is import-only (no update, no replace).

Fixes:
  * aws_codepipeline      timeout_in_minutes = 0          -> removed
  * aws_launch_template   security_group_names/vpc_security_group_ids = [] -> removed
                          throughput = 0 / volume_initialization_rate = 0 -> removed
  * aws_dms_endpoint      port = 0 (with secrets_manager_*) -> removed
  * aws_sns_topic         signature_version = 0            -> removed
  * aws_instance          ipv6_address_count = 0 + ipv6_addresses = [] -> removed
  * aws_route_table       inline route "" values           -> null
  * aws_lambda_function   no code source -> filename = placeholder zip,
                          lifecycle ignore_changes [filename, source_code_hash]
                          (AWS never returns the code; this keeps the live code)
  * aws_ssm_parameter     value = null -> live value (String) or placeholder
                          (SecureString) + ignore_changes [value, insecure_value]
  * aws_key_pair          public_key = null -> real key from
                          `aws ec2 describe-key-pairs --include-public-key`
                          (placeholder if the CLI call fails) + ignore_changes
                          [public_key] so it can never force a replacement
"""
import json, os, re, subprocess, sys, zipfile

args = sys.argv[1:]
if not args:
    sys.exit(__doc__)
path = args[0]
profile = None
if "--profile" in args:
    profile = args[args.index("--profile") + 1]

src = open(path).read().splitlines()
out_dir = os.path.dirname(os.path.abspath(path))

PLACEHOLDER_ZIP = "legacy_lambda_placeholder.zip"
zip_path = os.path.join(out_dir, PLACEHOLDER_ZIP)

def hcl_str(v):
    """JSON-quote a string and escape HCL template sequences (${ and %{)."""
    return json.dumps(v).replace("${", "$${").replace("%{", "%%{")

def kv(line):
    m = re.match(r'^\s*([a-z0-9_]+)\s*=\s*(.*?)\s*$', line)
    return (m.group(1), m.group(2)) if m else (None, None)

def key_public(name):
    cmd = ["aws", "ec2", "describe-key-pairs", "--include-public-key",
           "--key-names", name, "--output", "json"]
    if profile:
        cmd += ["--profile", profile]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return json.loads(r.stdout)["KeyPairs"][0]["PublicKey"].strip()
    except Exception as e:  # noqa
        print(f"  ! could not fetch public key for {name}: {e}", file=sys.stderr)
        return None

def ssm_value(name):
    cmd = ["aws", "ssm", "get-parameter", "--name", name, "--output", "json"]
    if profile:
        cmd += ["--profile", profile]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return json.loads(r.stdout)["Parameter"]["Value"]
    except Exception as e:  # noqa
        print(f"  ! could not fetch SSM parameter {name}: {e}", file=sys.stderr)
        return None

# split into top-level blocks
blocks, cur = [], []
for line in src:
    cur.append(line)
    if line == "}":
        blocks.append(cur); cur = []
if cur:
    blocks.append(cur)

stats = {}
def hit(k): stats[k] = stats.get(k, 0) + 1

result = []
for b in blocks:
    head = next((l for l in b if l.strip() and not l.lstrip().startswith("#")), "")
    m = re.match(r'^resource "([^"]+)" "([^"]+)"', head)
    rtype = m.group(1) if m else ""
    body = b
    extra_ignore = []

    if rtype == "aws_codepipeline":
        body = [l for l in body if kv(l) != ("timeout_in_minutes", "0")]
    elif rtype == "aws_launch_template":
        body = [l for l in body if kv(l) not in (
            ("security_group_names", "[]"), ("vpc_security_group_ids", "[]"),
            ("throughput", "0"), ("volume_initialization_rate", "0"))]
    elif rtype == "aws_dms_endpoint":
        if any(kv(l)[0] == "secrets_manager_arn" and kv(l)[1] != "null" for l in body):
            body = [l for l in body if kv(l) != ("port", "0")]
    elif rtype == "aws_sns_topic":
        body = [l for l in body if kv(l) != ("signature_version", "0")]
    elif rtype == "aws_instance":
        body = [l for l in body if kv(l) not in (
            ("ipv6_address_count", "0"), ("ipv6_addresses", "[]"))]
    elif rtype == "aws_route_table":
        inroute, nb = False, []
        for l in body:
            if re.match(r'^\s*route\s*=\s*\[', l):
                inroute = True
            if inroute:
                l = re.sub(r'=\s*""\s*$', "= null", l)
                if re.match(r'^\s*\}\]\s*$', l) or re.match(r'^\s*\]\s*$', l):
                    inroute = False
            nb.append(l)
        body = nb
    elif rtype == "aws_lambda_function":
        pkg = next((kv(l)[1] for l in body if kv(l)[0] == "package_type"), '"Zip"')
        if pkg.strip('"') == "Zip":
            nb = []
            for l in body:
                k, v = kv(l)
                if k == "filename" and v == "null":
                    l = re.sub(r'null\s*$', f'"{PLACEHOLDER_ZIP}"', l)
                nb.append(l)
            body = nb
            extra_ignore = ["filename", "source_code_hash"]
        else:
            print(f"  ! {m.group(2)} is an Image lambda: set image_uri by hand", file=sys.stderr)
    elif rtype == "aws_ssm_parameter":
        # SSM values are never written by -generate-config-out. String params:
        # fetch the live value into insecure_value; SecureString: placeholder.
        # ignore_changes keeps Terraform from ever rewriting the live value.
        ptype = next((kv(l)[1].strip('"') for l in body if kv(l)[0] == "type"), "String")
        pname = next((kv(l)[1].strip('"') for l in body if kv(l)[0] == "name"), None)
        body = [l for l in body if not (kv(l)[0] in ("value", "value_wo", "insecure_value")
                                         and kv(l)[1].startswith("null"))]
        if ptype == "SecureString":
            body = body[:-1] + ['  value = "placeholder-real-value-kept-by-ignore_changes"'] + body[-1:]
        else:
            live = ssm_value(pname) if pname else None
            body = body[:-1] + [f"  insecure_value = {hcl_str(live if live is not None else 'placeholder')}"] + body[-1:]
        extra_ignore = ["value", "insecure_value"]
    elif rtype == "aws_key_pair":
        kname = next((kv(l)[1].strip('"') for l in body if kv(l)[0] == "key_name"), None)
        pub = key_public(kname) if kname else None
        pub = pub or "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPLACEHOLDERPLACEHOLDERPLACEHOLDERPLACEHOLD placeholder"
        body = [re.sub(r'null\s*$', lambda _m: hcl_str(pub), l) if kv(l) == ("public_key", "null") else l
                for l in body]
        extra_ignore = ["public_key"]

    if extra_ignore and not any(re.match(r'^\s*lifecycle\s*\{', l) for l in body):
        body = body[:-1] + ["  lifecycle {",
                            f"    ignore_changes = [{', '.join(extra_ignore)}]",
                            "  }"] + body[-1:]
    if body != b:
        hit(rtype)
    result.extend(body)

open(path, "w").write("\n".join(result) + "\n")

if stats.get("aws_lambda_function") and not os.path.exists(zip_path):
    with zipfile.ZipFile(zip_path, "w") as z:
        z.writestr("README.txt", "Placeholder: real code lives in AWS; ignore_changes keeps it.\n")

for k, v in sorted(stats.items()):
    print(f"  fixed {v:3d} x {k}")
print(f"done: {path}")
