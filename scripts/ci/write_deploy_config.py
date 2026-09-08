#!/usr/bin/env python3
"""Validate push/account isolation and write non-secret Terraform inputs for CI."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import sys


def configuration(env: dict[str, str]) -> tuple[str, dict, str]:
    target = env.get("DEPLOY_ENV", "")
    if target not in {"dev", "main"}:
        raise ValueError("Only dev and main are deployment environments")
    if env.get("GITHUB_EVENT_NAME") != "push" or env.get("GITHUB_REF") != f"refs/heads/{target}":
        raise ValueError("Deployment requires a push to the matching protected branch")
    account = env.get("AWS_ACCOUNT_ID", "")
    region = env.get("AWS_REGION", "")
    if not re.fullmatch(r"\d{12}", account) or not re.fullmatch(r"[a-z]{2}-[a-z]+-\d+", region):
        raise ValueError("Set this GitHub environment's AWS_ACCOUNT_ID and AWS_REGION variables")
    values = json.loads(env.get("TF_VARS_JSON", ""))
    if not isinstance(values, dict) or values.get("account_id") != account:
        raise ValueError("TF_VARS_JSON account_id must match the GitHub environment's AWS_ACCOUNT_ID")
    if not re.fullmatch(r"\d{12}", values.get("peer_account_id", "")) or values["peer_account_id"] == account:
        raise ValueError("Dev and main must use different AWS accounts")
    if values.get("aws_region", region) != region:
        raise ValueError("Terraform and GitHub AWS regions disagree")
    values["aws_region"] = region
    project = values.get("project", "agrovesto")
    if not re.fullmatch(r"[a-z][a-z0-9-]{2,15}", project):
        raise ValueError("Invalid project slug")
    if env.get("AWS_ROLE_ARN") != f"arn:aws:iam::{account}:role/{project}-bootstrap-{target}-deploy":
        raise ValueError("AWS_ROLE_ARN must be the matching account bootstrap deployment role")
    boundary = f"arn:aws:iam::{account}:policy/{project}-bootstrap-{target}-workload-boundary"
    if values.get("permissions_boundary_arn") != boundary:
        raise ValueError("Wrong account/environment workload permissions boundary")
    bucket = env.get("TF_STATE_BUCKET", "")
    if bucket != f"{project}-tfstate-{account}-{region}":
        raise ValueError("TF_STATE_BUCKET must match this account's bootstrap output")
    key = env.get("TF_STATE_KMS_KEY_ARN", "")
    if not re.fullmatch(rf"arn:aws:kms:{re.escape(region)}:{account}:key/[a-f0-9-]{{36}}", key):
        raise ValueError("Use the matching account's bootstrap state KMS key ARN, not an alias or another account's key")
    backend = "\n".join([
        f"bucket = {json.dumps(bucket)}", f'key = "{target}/terraform.tfstate"',
        f"region = {json.dumps(region)}", "encrypt = true", "use_lockfile = true",
        f"kms_key_id = {json.dumps(key)}", f"allowed_account_ids = [{json.dumps(account)}]", "",
    ])
    return target, values, backend


def write_files(env: dict[str, str]) -> tuple[Path, Path]:
    target, values, backend = configuration(env)
    root = Path(env.get("GITHUB_WORKSPACE", ".")) / "environments" / target
    if not root.is_dir():
        raise ValueError("Deployment root does not exist")
    backend_path = Path(env["RUNNER_TEMP"]) / f"backend-{target}.hcl"
    tfvars_path = root / "ci.auto.tfvars.json"
    for path, content in [(tfvars_path, json.dumps(values, indent=2) + "\n"), (backend_path, backend)]:
        with open(path, "w", opener=lambda name, flags: os.open(name, flags, 0o600)) as handle:
            handle.write(content)
        path.chmod(0o600)
    return root, backend_path


def main() -> None:
    root, backend = write_files(dict(os.environ))
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write(f"root={root}\nbackend={backend}\n")
    print("Validated push, account, role, state and permissions boundary. No input values were printed.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        print(f"Deployment configuration rejected: {error}", file=sys.stderr)
        sys.exit(1)
