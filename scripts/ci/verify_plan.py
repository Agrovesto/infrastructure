#!/usr/bin/env python3
"""Fail closed on protected data deletion and known unsafe changes in a saved plan.

Unknown attributes (normal on first creation) are checked by source scans/mock
contracts instead. This is an extra deployment guard, not a replacement for them.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

PROTECTED = {
    "aws_db_instance", "aws_ebs_volume", "aws_s3_bucket", "aws_kms_key",
    "aws_ecr_repository", "aws_route53_zone", "aws_backup_vault", "aws_secretsmanager_secret",
}


def resources(module: dict):
    yield from module.get("resources", [])
    for child in module.get("child_modules", []):
        yield from resources(child)


def violations(plan: dict) -> list[str]:
    errors = []
    if plan.get("errored") or plan.get("applyable") is False:
        errors.append("The saved plan is not applyable")
    for change in plan.get("resource_changes", []):
        if change.get("mode", "managed") == "managed" and change["type"] in PROTECTED and "delete" in change["change"]["actions"]:
            errors.append(f"Protected data deletion/replacement: {change['address']}")
    for resource in resources(plan.get("planned_values", {}).get("root_module", {})):
        if resource.get("mode", "managed") != "managed":
            continue
        kind, values, address = resource["type"], resource.get("values", {}), resource["address"]
        if kind == "aws_db_instance":
            required = {"engine": "sqlserver-se", "license_model": "license-included", "storage_encrypted": True,
                        "publicly_accessible": False, "multi_az": True, "deletion_protection": True,
                        "manage_master_user_password": True, "skip_final_snapshot": False}
            for key, expected in required.items():
                if key in values and values[key] is not None and values[key] != expected:
                    errors.append(f"Unsafe RDS {key}: {address}")
        if kind == "aws_instance":
            if values.get("associate_public_ip_address") is True:
                errors.append(f"Public EC2 address: {address}")
            for options in values.get("metadata_options", []):
                if options.get("http_tokens") not in (None, "required"):
                    errors.append(f"IMDSv2 is not required: {address}")
            for volume in values.get("root_block_device", []):
                if volume.get("encrypted") is False:
                    errors.append(f"Unencrypted root disk: {address}")
        if kind == "aws_ebs_volume" and values.get("encrypted") is False:
            errors.append(f"Unencrypted database disk: {address}")
        if kind == "aws_ecs_service":
            for network in values.get("network_configuration", []):
                if network.get("assign_public_ip") is True:
                    errors.append(f"Public ECS task: {address}")
        if kind == "aws_ecs_task_definition" and values.get("container_definitions"):
            for container in json.loads(values["container_definitions"]):
                if container.get("privileged") or not container.get("readonlyRootFilesystem"):
                    errors.append(f"Privileged/writable ECS container: {address}")
                if container.get("user", "0").split(":")[0] in {"0", "root", ""}:
                    errors.append(f"Root ECS container: {address}")
                if any(e.get("name") in {"DB_PASSWORD", "MSSQL_SA_PASSWORD"} for e in container.get("environment", [])):
                    errors.append(f"Plaintext DB credentials in task definition: {address}")
        if kind == "aws_vpc_security_group_ingress_rule" and (values.get("cidr_ipv4") == "0.0.0.0/0" or values.get("cidr_ipv6") == "::/0"):
            if not (address.startswith("module.edge.") and values.get("ip_protocol") == "tcp" and
                    values.get("from_port") == values.get("to_port") and values.get("from_port") in {80, 443}):
                errors.append(f"Unexpected public ingress: {address}")
    return errors


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    args = parser.parse_args()
    errors = violations(json.loads(args.plan.read_text()))
    if errors:
        print("\n".join(errors), file=sys.stderr)
        sys.exit(1)
    print("Saved plan passed the data-deletion and known-security-attribute guards.")


if __name__ == "__main__":
    main()
