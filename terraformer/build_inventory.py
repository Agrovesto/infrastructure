#!/usr/bin/env python3

from pathlib import Path
import csv
import re

BASE = Path.home() / "infrastructure" / "terraformer"

ACCOUNTS = {
    "agrovesto-dev": BASE / "dev" / "generated" / "aws",
    "agrovesto-prod": BASE / "agrovesto-prod" / "generated" / "aws",
}

OUTPUT = BASE / "aws-inventory.csv"


RESOURCE_RE = re.compile(
    r'^\s*resource\s+"([^"]+)"\s+"([^"]+)"\s*\{',
    re.MULTILINE,
)

DATA_RE = re.compile(
    r'^\s*data\s+"([^"]+)"\s+"([^"]+)"\s*\{',
    re.MULTILINE,
)


def extract_block(text: str, start: int) -> str:
    brace_start = text.find("{", start)
    if brace_start == -1:
        return ""

    depth = 0
    in_string = False
    escape = False

    for i in range(brace_start, len(text)):
        char = text[i]

        if escape:
            escape = False
            continue

        if char == "\\" and in_string:
            escape = True
            continue

        if char == '"':
            in_string = not in_string
            continue

        if in_string:
            continue

        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1

            if depth == 0:
                return text[brace_start:i + 1]

    return text[brace_start:]


def extract_value(block: str, key: str) -> str:
    match = re.search(
        rf'^\s*{re.escape(key)}\s*=\s*"([^"]*)"',
        block,
        re.MULTILINE,
    )

    if match:
        return match.group(1)

    return ""


def detect_region(block: str, file_path: Path) -> str:
    match = re.search(
        r'provider\s*=\s*"?aws\.([A-Za-z0-9-]+)"?',
        block,
    )

    if match:
        return match.group(1)

    # Terraformer can place region in provider configuration.
    provider_match = re.search(
        r'provider\s*=\s*"aws"',
        block,
    )

    if provider_match:
        region = re.search(
            r'region\s*=\s*"([^"]+)"',
            block,
        )

        if region:
            return region.group(1)

    return "unknown"


rows = []

for account, root in ACCOUNTS.items():

    if not root.exists():
        print(f"WARNING: {root} does not exist")
        continue

    for tf_file in root.rglob("*.tf"):

        try:
            text = tf_file.read_text(errors="ignore")
        except Exception as exc:
            print(f"WARNING: Could not read {tf_file}: {exc}")
            continue

        # Service is the first directory below generated/aws
        try:
            relative = tf_file.relative_to(root)
            service = relative.parts[0] if relative.parts else "unknown"
        except ValueError:
            service = "unknown"

        # Terraform resources
        for match in RESOURCE_RE.finditer(text):
            resource_type = match.group(1)
            resource_name = match.group(2)

            block = extract_block(text, match.start())

            provider = extract_value(block, "provider")
            region = detect_region(block, tf_file)

            resource_id = extract_value(block, "id")
            arn = extract_value(block, "arn")
            name = extract_value(block, "name")

            rows.append({
                "account": account,
                "region": region,
                "service": service,
                "terraform_type": "resource",
                "resource_type": resource_type,
                "resource_name": resource_name,
                "name": name,
                "id": resource_id,
                "arn": arn,
                "provider": provider,
                "file": str(tf_file.relative_to(BASE)),
            })

        # Terraform data sources
        for match in DATA_RE.finditer(text):
            data_type = match.group(1)
            data_name = match.group(2)

            block = extract_block(text, match.start())

            provider = extract_value(block, "provider")
            region = detect_region(block, tf_file)

            resource_id = extract_value(block, "id")
            arn = extract_value(block, "arn")
            name = extract_value(block, "name")

            rows.append({
                "account": account,
                "region": region,
                "service": service,
                "terraform_type": "data",
                "resource_type": data_type,
                "resource_name": data_name,
                "name": name,
                "id": resource_id,
                "arn": arn,
                "provider": provider,
                "file": str(tf_file.relative_to(BASE)),
            })


fields = [
    "account",
    "region",
    "service",
    "terraform_type",
    "resource_type",
    "resource_name",
    "name",
    "id",
    "arn",
    "provider",
    "file",
]

rows.sort(
    key=lambda x: (
        x["account"],
        x["region"],
        x["service"],
        x["resource_type"],
        x["resource_name"],
    )
)

with OUTPUT.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fields)
    writer.writeheader()
    writer.writerows(rows)

print()
print(f"Inventory written to: {OUTPUT}")
print(f"Total entries: {len(rows)}")

for account in ACCOUNTS:
    count = sum(1 for row in rows if row["account"] == account)
    print(f"{account}: {count}")

print()
print("Service counts:")

service_counts = {}
for row in rows:
    key = (row["account"], row["service"])
    service_counts[key] = service_counts.get(key, 0) + 1

for (account, service), count in sorted(service_counts.items()):
    print(f"{account:20} {service:25} {count}")
