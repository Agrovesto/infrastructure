#!/usr/bin/env python3
"""Turn the Resource Explorer inventory into Terraform import blocks.

Input : imports/inventory/{dev,prod}.arns  (one ARN per line, from the
        AGROVESTO-AWS-INVENTORY-20260923 report)
Output: imports/{dev,prod,monitoring}/imports_legacy.tf, imports/INVENTORY_MAP.md
        (staged into the stack by imports/stage.sh, never committed there)

Every ARN gets exactly one decision:

  ADOPT    - becomes an address the new design already declares
             (see imports/<stack>/imports_adopt.tf)
  IMPORT   - standalone resource the new design does not model; imported
             under a `legacy_*` address, config via -generate-config-out
  CONFIRM  - importable, but the import id or ownership needs one fact from
             imports/discover.sh first (block emitted commented out)
  STACK    - owned by a CloudFormation stack that Terraform manages as a
             whole (aws_cloudformation_stack); importing the child too would
             give it two owners
  BOOTSTRAP- managed by the bootstrap stack (bootstrap/imports.tf)
  SKIP     - cannot / must not be managed: AWS-owned defaults, runtime
             objects, service-managed ENIs, backups, inline SG rules

Re-run after editing the lists:  python3 imports/classify.py
"""
from __future__ import annotations

import re
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INV = ROOT / "imports" / "inventory"

ACCOUNTS = {"dev": "353833416626", "prod": "221434544570"}

# ---------------------------------------------------------------------------
# Adoption: existing resources that become addresses in the new design.
# Values here are the ones we can prove from the ARNs alone; the rest of
# var.adopt is filled from imports/discover.sh output.
# ---------------------------------------------------------------------------
ADOPT = {
    "dev": {
        "vpc/vpc-0d9b566c353787d53": "aws_vpc.main (imports/<stack>/imports_adopt.tf)",
        "internet-gateway/igw-04e4d65d903b2b67d": "aws_internet_gateway.main (imports_adopt.tf)",
        "apps/d3v79u00ot9glq": 'aws_amplify_app.this["onboarding"] (imports_adopt.tf)',
        "apps/d3v79u00ot9glq/branches/dev": 'aws_amplify_branch.this["onboarding"] (imports_adopt.tf)',
        "apps/dfvk5chhp2iln": 'aws_amplify_app.this["landing"] (imports_adopt.tf)',
        "apps/dfvk5chhp2iln/branches/staging": 'aws_amplify_branch.this["landing"] (imports_adopt.tf)',
        "security-group/sg-032197de8d143373f": "aws_default_security_group.default[0] (no rules today - safe to strip)",
        "subnet/subnet-0739cfd4c412deb3f": "aws_subnet.public[0] (172.96.0.0/24, eu-west-1a - hosts the app EC2)",
        "route-table/rtb-018e7f1b9df073189": "aws_route_table.public (+ association and 0.0.0.0/0 route)",
    },
    "prod": {
        "vpc/vpc-0016f521bae08f4ff": "aws_vpc.main (imports/<stack>/imports_adopt.tf)",
        "internet-gateway/igw-07275a1a62726a4c8": "aws_internet_gateway.main (imports_adopt.tf)",
        "db:migration-prod": "aws_db_instance.mssql (imports_adopt.tf; var.mssql_identifier = migration-prod)",
        "subgrp:agxdb2subnetgroup": "aws_db_subnet_group.mssql (migration-prod's group)",
        "subnet/subnet-0b808deeaf8391867": "aws_subnet.public[0] (172.96.0.0/24, eu-west-1a)",
        "subnet/subnet-0e169f40c70cdfe8b": "aws_subnet.public[1] (172.96.1.0/24, eu-west-1b)",
        "subnet/subnet-00ee6901e53783c86": "aws_subnet.database[0] (172.96.2.0/24, eu-west-1a - migration-prod lives here)",
        "subnet/subnet-084f21457f316c44c": "aws_subnet.database[1] (172.96.3.0/24, eu-west-1b - migration-prod lives here)",
        "route-table/rtb-0530eb261b38f735b": "aws_route_table.public",
        "route-table/rtb-0fa42099da11b78e9": "aws_route_table.private[0] (gains the NAT route)",
        "route-table/rtb-084528a52ec739f38": "aws_route_table.private[1] (gains the NAT route)",
    },
}


# ---------------------------------------------------------------------------
# FACTS from imports/discovery-{dev,prod}.txt (2026-09-23). They turn CONFIRM
# rows into concrete ADOPT / IMPORT / SKIP decisions.
# ---------------------------------------------------------------------------
KEY_PAIR_NAMES = {
    "key-0748e9b8e2b76c283": "noma-api", "key-0abcffe745fbd2ac6": "nomas-api",
    "key-075e7652029e2c2c5": "noma-agx", "key-057e0d6c32eb78e4d": "rdsjumpserverkeypair",
    "key-0b6382b8152c63533": "deployment-ssh",
}
CUSTOMER_KMS_KEYS = {"31f57b1f-cbde-4aa6-8c6e-18e129c80fb6"}  # alias/nomaos-bootstrap-dev; all others are aws/*
DMS_ENDPOINT_IDS = {
    "agxdb": "agxdb2instance", "WFZ6YQ2JCJBLLBLRDLCH7XNRWY": "agxdb-snapshot-restore",
    "BSI5NFYJSVELZMYVPFOMJ56MIM": "nomaosdbinstance", "nomaos": "nomaosinstance-snapshot-restore",
}
ROOT_VOLUMES = {"vol-082127f70f11b82b9", "vol-00f63527a001045fa", "vol-019ff51ce045e3490"}
DEFAULT_SGS = {"dev": "sg-032197de8d143373f", "prod": "sg-05a2722a050c1109b"}
MAIN_ROUTE_TABLES = {"rtb-0faede26619f355d8": "vpc-0d9b566c353787d53",
                     "rtb-0fa0841a7b7dac5db": "vpc-0016f521bae08f4ff"}

# Subnets / route tables / default SG / NACL of the adopted VPCs: which one
# becomes public[0], database[1], ... depends on CIDR + route, so they are
# CONFIRM until discover.sh shows them (they are listed in var.adopt then).
VPC_CHILD_TYPES = {"subnet", "route-table"}

# CloudFormation stacks Terraform will own as a whole.
STACK_OWNED = [
    # (stack name prefix, predicate on the resource tail)
    ("CDKToolkit", lambda t: "cdk-hnb659fds" in t),
    ("Infra-ECS-Cluster-agrovesto-dev", lambda t: t == "cluster/agrovesto-dev"),
    ("agrovesto-infra-pipeline", lambda t: t in (
        "agrovesto-ProdPipeline", "webhook:agrovesto-ProdWebhook",
        "project/agrovesto-ProdCodeBuildProject")),
]
MANAGED_STACKS = ("CDKToolkit", "Infra-ECS-Cluster-", "agrovesto-infra-pipeline")
# Stacks that are dismantled (DeletionPolicy=Retain, then delete) because
# their resources are adopted/imported individually - see RUNBOOK phase 0.
DECOUPLED_STACKS = ("agrovesto-infra-deployment",)

# Prod-account resources that belong to observability -> monitoring stack.
MONITORING_LOGS = {"ec2-auth", "ec2-syslog", "ec2-kernel", "ec2-cloud-init",
                   "ec2-cloud-init-output", "nginx-access", "nginx-error",
                   "RDSOSMetrics"}
MONITORING_OTHER = {"parameter/AmazonCloudWatch-linux",
                    "association/ef34e30b-8367-4e4e-96d6-573010af70ef"}

SKIP_REASONS = {
    "security-group-rule": "inline rule of its security group; captured by the parent aws_security_group import",
    "network-interface": "service-managed ENI (EC2/RDS/Lambda/DMS); owned by the resource it is attached to",
    "snapshot": "backup artifact; retain via lifecycle policy / AWS Backup, not IaC",
    "auto-backup": "RDS retained automated backup; not a Terraform resource",
    "managed-instance": "SSM runtime registration of an instance",
    "session": "SSM Session Manager session (runtime)",
    "og": "AWS default option group (read-only, cannot be managed)",
    "pg": "AWS default parameter group (read-only, cannot be managed)",
    "parametergroup": "AWS default MemoryDB parameter group",
    "memorydb-default": "AWS default MemoryDB user/ACL",
    "elasticache-default": "AWS default ElastiCache user",
    "xray-default": "AWS default X-Ray sampling rule",
    "athena-default": "AWS default Athena catalog/workgroup (cannot be deleted)",
    "events-default": "AWS default event bus",
    "apprunner-default": "AWS default App Runner autoscaling configuration",
    "dhcp-default": "AWS default DHCP option set",
    "user-notifications": "rule owned by AWS User Notifications",
    "lambda-version": "$LATEST is part of the function, not a separate resource",
    "rds-managed-secret": "owned by RDS (manage_master_user_password); prod reads it via aws_db_instance.master_user_secret",
    "tfstate": "",
}


def slug(s: str) -> str:
    s = re.sub(r"[^A-Za-z0-9]+", "_", s).strip("_").lower()
    if not s or s[0].isdigit():
        s = "r_" + s
    return s[:60]


def classify(env: str, arn: str):
    """-> (decision, stack, tf_type, name, import_id, note)"""
    parts = arn.split(":", 5)
    service = parts[2]
    tail = parts[5]
    acct = ACCOUNTS[env]
    stack = env

    # ---- adoption --------------------------------------------------------
    for key, target in ADOPT.get(env, {}).items():
        if tail == key:
            return ("ADOPT", env, None, None, None, target)

    # ---- CloudFormation --------------------------------------------------
    if service == "cloudformation":
        sname = tail.split("/")[1]
        if sname.startswith(MANAGED_STACKS):
            return ("IMPORT", env, "aws_cloudformation_stack", "legacy_" + slug(sname), sname,
                    "Terraform owns the stack; its children are not imported separately")
        return ("SKIP", env, None, None, None,
                "decoupled in RUNBOOK phase 0 (DeletionPolicy=Retain, then delete stack); its resources are imported individually")

    for prefix, pred in STACK_OWNED:
        if pred(tail):
            return ("STACK", env, None, None, None, f"owned by CloudFormation stack {prefix}*")

    # ---- skips -----------------------------------------------------------
    rtype = tail.split("/")[0].split(":")[0]
    if rtype in ("security-group-rule", "network-interface", "snapshot", "managed-instance", "session"):
        return ("SKIP", env, None, None, None, SKIP_REASONS[rtype])
    if service == "rds" and rtype in ("og", "pg", "snapshot", "auto-backup"):
        return ("SKIP", env, None, None, None, SKIP_REASONS["snapshot" if rtype == "snapshot" else rtype])
    if service == "memorydb":
        return ("SKIP", env, None, None, None, SKIP_REASONS["parametergroup" if rtype == "parametergroup" else "memorydb-default"])
    if service == "elasticache":
        return ("SKIP", env, None, None, None, SKIP_REASONS["elasticache-default"])
    if service == "xray":
        return ("SKIP", env, None, None, None, SKIP_REASONS["xray-default"])
    if service == "athena":
        return ("SKIP", env, None, None, None, SKIP_REASONS["athena-default"])
    if service == "events" and tail == "event-bus/default":
        return ("SKIP", env, None, None, None, SKIP_REASONS["events-default"])
    if service == "events" and "AWSUserNotificationsManagedRule" in tail:
        return ("SKIP", env, None, None, None, SKIP_REASONS["user-notifications"])
    if service == "apprunner" and rtype == "autoscalingconfiguration":
        return ("SKIP", env, None, None, None, SKIP_REASONS["apprunner-default"])
    if service == "ec2" and rtype == "dhcp-options":
        return ("SKIP", env, None, None, None, SKIP_REASONS["dhcp-default"])
    if service == "lambda" and tail.endswith(":$LATEST"):
        return ("SKIP", env, None, None, None, SKIP_REASONS["lambda-version"])
    if service == "secretsmanager" and tail.startswith("secret:rds!"):
        return ("SKIP", env, None, None, None, SKIP_REASONS["rds-managed-secret"])
    if service == "s3" and tail.startswith("nomaos-tfstate-") and "-logs-" not in tail:
        return ("BOOTSTRAP", "bootstrap", None, None, None, "aws_s3_bucket.state (bootstrap/imports.tf)")

    # ---- monitoring routing (prod account only) --------------------------
    if env == "prod":
        if service == "logs" and tail.split(":", 1)[1] in MONITORING_LOGS:
            stack = "monitoring"
        if service == "ssm" and tail in MONITORING_OTHER:
            stack = "monitoring"

    # ---- importable ------------------------------------------------------
    if service == "ec2":
        rid = tail.split("/", 1)[1]
        if rtype == "route-table" and rid in MAIN_ROUTE_TABLES:
            return ("IMPORT", stack, "aws_default_route_table", "legacy_main_" + slug(rid), MAIN_ROUTE_TABLES[rid],
                    "the VPC's main route table (no subnets associated)")
        if rtype in VPC_CHILD_TYPES:
            return ("IMPORT", stack, {"subnet": "aws_subnet", "route-table": "aws_route_table"}[rtype],
                    "legacy_" + slug(rid), rid, "not used by the new design; review for deletion after cut-over")
        if False:
            t = {"subnet": "aws_subnet", "route-table": "aws_route_table"}[rtype]
            return ("CONFIRM", stack, t, "legacy_" + slug(rid), rid,
                    "child of the adopted VPC: uncomment EITHER here (legacy) OR the matching slot in imports_adopt.tf, per discover.sh")
        if rtype == "network-acl":
            return ("IMPORT", stack, "aws_default_network_acl", "legacy_" + slug(rid), rid,
                    "the VPC's default NACL; generated config must list its subnet_ids")
        if rtype == "security-group" and rid == DEFAULT_SGS[env]:
            return ("IMPORT", stack, "aws_default_security_group", "legacy_default", rid,
                    "default SG with LIVE rules (attached to migration-prod + EC2): kept as-is, manage_default_security_group = false")
        if rtype == "security-group":
            return ("IMPORT", stack, "aws_security_group", "legacy_" + slug(rid), rid, "")
        if False:
            return ("CONFIRM", stack, "aws_security_group", "legacy_" + slug(rid), rid,
                    "if discover.sh marks it DEFAULT, leave commented: aws_default_security_group.default adopts it")
        m = {
            "instance": ("aws_instance", None),
            "volume": ("aws_ebs_volume", "root volumes stay with their aws_instance - drop this block if discover.sh marks it ROOT"),
            "elastic-ip": ("aws_eip", None),
            "launch-template": ("aws_launch_template", None),
            "image": ("aws_ami", "custom AMI; generated config pins its snapshots"),
        }
        if rtype == "volume" and rid in ROOT_VOLUMES:
            return ("SKIP", stack, None, None, None, "root volume: managed through its aws_instance (root_block_device)")
        if rtype in m:
            t, note = m[rtype]
            note = "" if rtype == "volume" else note
            return ("IMPORT", stack, t, "legacy_" + slug(rid), rid, note or "")
        if rtype == "key-pair":
            return ("IMPORT", stack, "aws_key_pair", "legacy_" + slug(KEY_PAIR_NAMES[rid]), KEY_PAIR_NAMES[rid],
                    "public key material only; add lifecycle ignore_changes = [public_key]")

    if service == "logs":
        name = tail.split(":", 1)[1]
        return ("IMPORT", stack, "aws_cloudwatch_log_group", "legacy_" + slug(name), name, "")
    if service == "lambda":
        name = tail.split(":", 1)[1]
        return ("IMPORT", stack, "aws_lambda_function", "legacy_" + slug(name), name,
                "generated config has no code source: add s3/filename or lifecycle ignore_changes (RUNBOOK 3.3)")
    if service == "s3":
        return ("IMPORT", stack, "aws_s3_bucket", "legacy_" + slug(tail), tail, "")
    if service == "kms":
        kid = tail.split("/", 1)[1]
        if kid not in CUSTOMER_KMS_KEYS:
            return ("SKIP", stack, None, None, None, "AWS-managed key (aws/*): owned by AWS, cannot be managed")
        return ("IMPORT", stack, "aws_kms_key", "legacy_key_" + kid[:8], kid, "customer key alias/nomaos-bootstrap-dev")
        return ("CONFIRM", stack, "aws_kms_key", "legacy_key_" + kid[:8], kid,
                "only customer-managed keys can be imported; discover.sh marks AWS-managed (aws/*) keys")
    if service == "secretsmanager":
        name = re.sub(r"-[A-Za-z0-9]{6}$", "", tail.split(":", 1)[1])
        return ("IMPORT", stack, "aws_secretsmanager_secret", "legacy_" + slug(name), arn,
                "secret metadata only - no aws_secretsmanager_secret_version, so no secret value enters state")
    if service == "rds" and rtype == "subgrp":
        name = tail.split(":", 1)[1]
        return ("IMPORT", stack, "aws_db_subnet_group", "legacy_" + slug(name), name,
                "if this is migration-prod's subnet group, use the aws_db_subnet_group.mssql slot in imports_adopt.tf instead")
    if service == "amplify":
        seg = tail.split("/")
        app = seg[1]
        if len(seg) == 2:
            return ("IMPORT", stack, "aws_amplify_app", "legacy_" + app, app, "")
        if seg[2] == "branches":
            return ("IMPORT", stack, "aws_amplify_branch", f"legacy_{app}_{slug(seg[3])}", f"{app}/{seg[3]}", "")
        if seg[2] == "domains":
            return ("IMPORT", stack, "aws_amplify_domain_association", f"legacy_{app}_{slug(seg[3])}", f"{app}/{seg[3]}", "")
    if service == "ecr":
        name = tail.split("/", 1)[1]
        return ("IMPORT", stack, "aws_ecr_repository", "legacy_" + slug(name), name, "")
    if service == "ecs":
        name = tail.split("/", 1)[1]
        return ("IMPORT", stack, "aws_ecs_cluster", "legacy_" + slug(name), name, "")
    if service == "events" and rtype == "rule":
        name = tail.split("/", 1)[1]
        return ("IMPORT", stack, "aws_cloudwatch_event_rule", "legacy_" + slug(name), f"default/{name}", "")
    if service == "codepipeline":
        if tail.startswith("webhook:"):
            return ("IMPORT", stack, "aws_codepipeline_webhook", "legacy_" + slug(tail[8:]), arn, "")
        return ("IMPORT", stack, "aws_codepipeline", "legacy_" + slug(tail), tail, "")
    if service == "codebuild":
        name = tail.split("/", 1)[1]
        return ("IMPORT", stack, "aws_codebuild_project", "legacy_" + slug(name), name, "")
    if service == "codeconnections":
        return ("IMPORT", stack, "aws_codeconnections_connection", "legacy_conn_" + tail.split("/")[1][:8], arn, "")
    if service == "codestar-connections":
        return ("IMPORT", stack, "aws_codestarconnections_connection", "legacy_conn_" + tail.split("/")[1][:8], arn, "")
    if service == "apprunner" and rtype == "connection":
        name = tail.split("/")[1]
        return ("IMPORT", stack, "aws_apprunner_connection", "legacy_" + slug(name), name, "")
    if service == "resource-explorer-2":
        t = "aws_resourceexplorer2_index" if rtype == "index" else "aws_resourceexplorer2_view"
        return ("IMPORT", stack, t, "legacy_" + rtype, arn, "")
    if service == "ssm" and rtype == "parameter":
        name = "/" + tail.split("/", 1)[1] if tail.count("/") > 1 else tail.split("/", 1)[1]
        if "cdk-bootstrap" in name:
            return ("STACK", env, None, None, None, "owned by CloudFormation stack CDKToolkit")
        return ("IMPORT", stack, "aws_ssm_parameter", "legacy_" + slug(name), name,
                "value enters state; for SecureString params prefer an ephemeral/data read")
    if service == "ssm" and rtype == "association":
        aid = tail.split("/", 1)[1]
        return ("IMPORT", stack, "aws_ssm_association", "legacy_assoc_" + aid[:8], aid, "")
    if service == "dms":
        if rtype == "subgrp":
            name = tail.split(":", 1)[1]
            return ("IMPORT", stack, "aws_dms_replication_subnet_group", "legacy_" + slug(name), name, "")
        rid = tail.split(":", 1)[1]
        eid = DMS_ENDPOINT_IDS[rid]
        return ("IMPORT", stack, "aws_dms_endpoint", "legacy_" + slug(eid), eid,
                "password is write-only: never read into state; keep it in Secrets Manager (secrets_manager_arn)")
    if service == "ses":
        name = tail.split("/", 1)[1]
        if rtype == "configuration-set":
            return ("IMPORT", stack, "aws_sesv2_configuration_set", "legacy_" + slug(name), name, "")
        if "@" in name:
            return ("IMPORT", stack, "aws_sesv2_email_identity", "legacy_" + slug(name), name, "")
        return ("IMPORT", stack, "aws_sesv2_email_identity", "legacy_" + slug(name), name, "domain identity")
    if service == "sns":
        return ("IMPORT", stack, "aws_sns_topic", "legacy_" + slug(tail), arn, "")
    if service == "acm":
        cid = tail.split("/", 1)[1]
        return ("IMPORT", stack, "aws_acm_certificate", "legacy_cert_" + cid[:8], arn,
                "if discover.sh shows *.nomaos.com + nomaos.com it can replace aws_acm_certificate.wildcard")

    return ("CONFIRM", stack, None, None, None, "unrecognised type - review manually")


HEADER = """# =============================================================================
# GENERATED by imports/classify.py from the 2026-09-23 AWS inventory
# ({account} / {env} account). Do not hand-edit: change classify.py and re-run.
#
# One-shot import blocks for existing resources the new design does not model.
# They have no resource blocks yet on purpose - Terraform writes them:
#
#   terraform plan -generate-config-out=generated_legacy.tf
#
# Review/clean generated_legacy.tf (RUNBOOK phase 3), apply, then unstage this
# file (imports/stage.sh --unstage). Import blocks are one-shot.
#
# Commented-out blocks need one fact from imports/discover.sh first.
# =============================================================================
"""


# Found by discover.sh, not indexed by Resource Explorer.
EXTRA = {
    "dev": [
        (f"ec2:association {sn}/{rt} (discover.sh)", "IMPORT", "dev", "aws_route_table_association",
         "legacy_" + slug(sn), f"{sn}/{rt}", "keeps the legacy subnet on its legacy route table")
        for sn, rt in [("subnet-0309fc43ea380ad6b", "rtb-05817e82c2f16f0a4"),
                       ("subnet-0304d72cd90dd43d9", "rtb-04a4e32b4443f50d5"),
                       ("subnet-004a7f9d9cbd53ea4", "rtb-0fea2a4ff5a3adf0f")]
    ] + [("route53:hostedzone/Z04841994LNF5EA00ZEG (dev.nomaos.com)", "IMPORT", "dev",
             "aws_route53_zone", "legacy_dev_nomaos_com", "Z04841994LNF5EA00ZEG",
             "delegated sub-zone; dev manages no DNS (manage_dns = false), so kept as legacy")],
    "prod": [
        ("ec2:association subnet-0e169f40c70cdfe8b/rtb-0614ed06de1bc1d89", "ADOPT", "prod", None, None, None,
         "aws_route_table_association.public[1] (in-place move to the shared public route table)"),
        ("route53:hostedzone/Z0208643NZ0W8WF5RQ9F (nomaos.com)", "ADOPT", "prod", None, None, None,
         "aws_route53_zone.this[0] (imports_adopt.tf)"),
        ("route53:hostedzone/Z00055662LTUSSMS5ZA84 (agrovesto.com)", "ADOPT", "prod", None, None, None,
         "aws_route53_zone.agrovesto (imports_adopt.tf)"),
    ],
}


def main():
    rows = []
    blocks = {"dev": [], "prod": [], "monitoring": []}
    for env in ("dev", "prod"):
        seen = set()
        for arn in (INV / f"{env}.arns").read_text().split():
            d, stack, t, name, iid, note = classify(env, arn)
            rows.append((env, d, stack, arn, f"{t}.{name}" if t else "", note))
            if d not in ("IMPORT", "CONFIRM") or not t:
                continue
            addr = f"{t}.{name}"
            n = 2
            while addr in seen:
                addr = f"{t}.{name}_{n}"
                n += 1
            seen.add(addr)
            rows[-1] = (env, d, stack, arn, addr, note)
            comment = f"# {arn}" + (f"\n# NOTE: {note}" if note else "")
            body = f'import {{\n  to = {addr}\n  id = "{iid}"\n}}'
            if d == "CONFIRM":
                body = "\n".join("# " + l for l in body.splitlines())
            blocks[stack].append((t, comment + "\n" + body))
        for src, d, stack, t, name, iid, note in EXTRA.get(env, []):
            rows.append((env, d, stack, src, f"{t}.{name}" if t else "", note))
            if t:
                blocks[stack].append((t, f"# {src} (discover.sh)\n# NOTE: {note}\nimport {{\n  to = {t}.{name}\n  id = \"{iid}\"\n}}"))

    for stack, items in blocks.items():
        env = "prod" if stack == "monitoring" else stack
        out = [HEADER.format(account=ACCOUNTS[env], env=env)]
        cur = None
        for t, b in sorted(items, key=lambda x: (x[0], x[1].split("\n")[-3] if "\n" in x[1] else x[1])):
            if t != cur:
                out.append(f"\n# --- {t} " + "-" * max(3, 70 - len(t)))
                cur = t
            out.append(b + "\n")
        (ROOT / "imports" / stack / "imports_legacy.tf").write_text("\n".join(out))

    # ---- markdown map ----------------------------------------------------
    md = ["# Inventory → Terraform map (generated by `imports/classify.py`)", "",
          "Every ARN from the 2026-09-23 inventory with exactly one decision. "
          "Legend in `imports/RUNBOOK.md` §1.", ""]
    for env in ("dev", "prod"):
        c = Counter(r[1] for r in rows if r[0] == env)
        md.append(f"## {env.upper()} ({ACCOUNTS[env]}) — {sum(c.values())} resources")
        md.append("")
        md.append(" · ".join(f"**{k}** {v}" for k, v in sorted(c.items())))
        md.append("")
        md.append("| Decision | Stack | ARN | Terraform address | Note |")
        md.append("|---|---|---|---|---|")
        order = ["ADOPT", "BOOTSTRAP", "IMPORT", "CONFIRM", "STACK", "SKIP"]
        for r in sorted((r for r in rows if r[0] == env), key=lambda r: (order.index(r[1]), r[2], r[4], r[3])):
            md.append(f"| {r[1]} | {r[2]} | `{r[3]}` | {('`'+r[4]+'`') if r[4] else ''} | {r[5]} |")
        md.append("")
    (ROOT / "imports" / "INVENTORY_MAP.md").write_text("\n".join(md))
    tot = Counter((r[0], r[1]) for r in rows)
    for k, v in sorted(tot.items()):
        print(k, v)
    print("total", len(rows))


if __name__ == "__main__":
    main()
