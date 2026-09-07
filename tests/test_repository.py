"""Offline structural regression tests supplement provider-schema mock plans.

These intentionally check actual HCL/YAML structures, not only string snapshots.
Application API/frontend unit tests belong in their own source repositories.
"""
from datetime import date
import json
from pathlib import Path
import re
import unittest

import hcl2
import yaml

ROOT = Path(__file__).resolve().parents[1]
TF_ROOTS = [ROOT / path for path in ("bootstrap/dev", "bootstrap/prod", "environments/dev", "environments/prod")]


def config(directory):
    merged = {}
    for path in sorted(directory.glob("*.tf")):
        document = hcl2.loads(path.read_text())
        for key, value in document.items():
            merged.setdefault(key, []).extend(value)
    return merged


def blocks(document, kind):
    return {key: value for block in document.get(kind, []) for key, value in block.items()}


def resource(directory, kind, name):
    for block in config(ROOT / directory).get("resource", []):
        if name in block.get(kind, {}):
            return block[kind][name]
    raise AssertionError(f"Missing {kind}.{name}")


class TerraformStructureTests(unittest.TestCase):
    def test_all_hcl_and_examples_parse(self):
        for path in ROOT.rglob("*"):
            if any(part in {".git", ".venv", ".tools", ".terraform", "node_modules"} for part in path.parts):
                continue
            if path.is_file() and (path.suffix in {".tf", ".hcl"} or path.name.endswith((".tfvars.example", ".hcl.example"))):
                with self.subTest(path=str(path.relative_to(ROOT))):
                    hcl2.loads(path.read_text())

    def test_local_module_calls_supply_exact_declared_inputs(self):
        directories = TF_ROOTS + list((ROOT / "modules").iterdir())
        for directory in directories:
            for name, call in blocks(config(directory), "module").items():
                target = (directory / call["source"]).resolve()
                self.assertTrue(target.is_dir())
                declarations = blocks(config(target), "variable")
                provided = set(call) - {"source", "version", "count", "for_each", "depends_on", "providers"}
                with self.subTest(module=f"{directory.name}/{name}"):
                    self.assertFalse(provided - declarations.keys(), "Unknown child module inputs")
                    self.assertFalse({key for key, value in declarations.items() if "default" not in value} - provided, "Missing required child module inputs")

    def test_root_account_guards_backend_and_locks(self):
        for directory in TF_ROOTS:
            doc = config(directory)
            aws = blocks(doc, "provider")["aws"]
            self.assertEqual(aws["allowed_account_ids"], ["${var.account_id}"])
            lock = hcl2.loads((directory / ".terraform.lock.hcl").read_text())
            provider = blocks(lock, "provider")["registry.terraform.io/hashicorp/aws"]
            self.assertEqual(provider["version"], "6.11.0")
            self.assertIn("zh:44d6581a1fc0b4f07569600bf6bee3b0bf5281fc82e6494bd72197f6335aa3e1", provider["hashes"])
            test_files = list((directory / "tests").glob("*.tftest.hcl"))
            self.assertTrue(test_files)
            for file in test_files:
                test = hcl2.loads(file.read_text())
                self.assertIn("aws", blocks(test, "mock_provider"))
                self.assertTrue(all(run["command"] == "${plan}" for run in blocks(test, "run").values()))
        for env in ("dev", "prod"):
            backend = (ROOT / f"environments/{env}/backend.hcl.example").read_text()
            parsed = hcl2.loads(backend)
            self.assertEqual(parsed["key"], f"{env}/terraform.tfstate")
            self.assertTrue(parsed["use_lockfile"] and parsed["encrypt"])

    def test_rds_sqlserver_settings_and_no_invalid_db_name(self):
        rds = resource("modules/rds_sqlserver", "aws_db_instance", "this")
        self.assertEqual(rds["engine"], "sqlserver-se")
        self.assertEqual(rds["license_model"], "license-included")
        self.assertNotIn("db_name", rds)
        self.assertNotIn("password", rds)
        self.assertFalse(rds["multi_az"])
        self.assertTrue(rds["manage_master_user_password"] and rds["storage_encrypted"])
        self.assertFalse(rds["publicly_accessible"] or rds["skip_final_snapshot"])
        self.assertEqual(rds["backup_retention_period"], 35)
        self.assertTrue(rds["lifecycle"][0]["prevent_destroy"])
        self.assertNotIn("multi_az", blocks(config(ROOT / "modules/rds_sqlserver"), "variable"))

    def test_no_terraform_secret_values_or_remote_exec(self):
        for directory in [*TF_ROOTS, *(ROOT / "modules").iterdir()]:
            for block in config(directory).get("resource", []):
                kind, named = next(iter(block.items()))
                self.assertNotIn(kind, {"random_password", "aws_secretsmanager_secret_version", "null_resource"})
                for value in named.values():
                    self.assertNotIn("provisioner", value)

    def test_dev_disk_is_independent_and_backed_up(self):
        host = resource("modules/dev_host", "aws_instance", "this")
        disk = resource("modules/dev_host", "aws_ebs_volume", "database")
        selection = resource("modules/dev_host", "aws_backup_selection", "this")
        self.assertNotIn("ebs_block_device", host)
        self.assertTrue(host["root_block_device"][0]["encrypted"] and disk["encrypted"])
        self.assertTrue(disk["lifecycle"][0]["prevent_destroy"])
        self.assertEqual(selection["resources"], ["${aws_ebs_volume.database.arn}"])
        self.assertNotIn("key_name", host)
        self.assertFalse(host["associate_public_ip_address"])

    def test_disk_scripts_fail_closed_and_mount_by_volume_id(self):
        installer = (ROOT / "scripts/dev/install.sh").read_text()
        starter = (ROOT / "scripts/dev/start.sh").read_text()
        self.assertIn("lsblk -dn -o PATH,SERIAL", installer)
        self.assertIn("wipefs --no-act", installer)
        self.assertNotRegex(installer, r"mkfs\.xfs\s+-f\s")
        self.assertIn("mountpoint -q /srv/mssql", starter)
        self.assertIn("RequiresMountsFor=/srv/mssql", (ROOT / "scripts/dev/agrovesto.service").read_text())

    def test_stateful_resources_have_destroy_guards(self):
        for directory, kind, name in [
            ("modules/storage", "aws_s3_bucket", "this"), ("modules/ecr", "aws_ecr_repository", "this"),
            ("modules/dns", "aws_route53_zone", "this"), ("modules/foundation", "aws_kms_key", "this"),
            ("modules/dev_host", "aws_backup_vault", "this"), ("modules/sql_secrets", "aws_secretsmanager_secret", "database"),
        ]:
            with self.subTest(kind=kind):
                self.assertTrue(resource(directory, kind, name)["lifecycle"][0]["prevent_destroy"])

    def test_scaffold_flags_edge_without_waf_and_nat_are_environment_specific(self):
        dev, prod = config(ROOT / "environments/dev"), config(ROOT / "environments/prod")
        self.assertFalse(blocks(dev, "variable")["services_enabled"]["default"])
        self.assertFalse(blocks(prod, "variable")["services_enabled"]["default"])
        # Edge keeps the ALB; WAF and Multi-AZ are not used.
        self.assertNotIn("enable_waf", blocks(prod, "module")["edge"])
        self.assertNotIn("enable_waf", blocks(dev, "module")["edge"])
        self.assertNotIn("enable_waf", blocks(prod, "variable"))
        self.assertNotIn("enable_waf", blocks(dev, "variable"))
        self.assertNotIn("multi_az", blocks(prod, "module")["database"])
        self.assertNotIn("rds_multi_az", blocks(prod, "variable"))
        edge = config(ROOT / "modules/edge")
        kinds = {next(iter(block)) for block in edge.get("resource", [])}
        self.assertNotIn("aws_wafv2_web_acl", kinds)
        self.assertIn("aws_lb", kinds)
        self.assertFalse(blocks(prod, "module")["network"]["single_nat_gateway"])
        self.assertTrue(blocks(dev, "module")["network"]["single_nat_gateway"])
        self.assertIn("frontends", blocks(dev, "module"))
        self.assertNotIn("frontends", blocks(prod, "module"))
        # Five APIs + two frontends are the default ECR layout.
        self.assertEqual(set(blocks(dev, "variable")["ecr_repositories"]["default"]),
                         {"core", "auth", "trading", "catalog", "notifications", "portal", "admin"})
        self.assertEqual(set(blocks(prod, "variable")["ecr_repositories"]["default"]),
                         {"core", "auth", "trading", "catalog", "notifications", "portal", "admin", "sql-admin"})

    def test_subnets_and_route_tables_isolate_databases(self):
        net = config(ROOT / "modules/network")
        for block in net.get("resource", []):
            for subnet in block.get("aws_subnet", {}).values():
                self.assertFalse(subnet["map_public_ip_on_launch"])
            for route in block.get("aws_route", {}).values():
                self.assertNotIn("database", route["route_table_id"])
        self.assertEqual(resource("modules/network", "aws_flow_log", "this")["traffic_type"], "ALL")

    def test_amplify_creates_dns_without_waiting_on_a_dependency(self):
        association = resource("modules/amplify", "aws_amplify_domain_association", "this")
        self.assertFalse(association["wait_for_verification"])
        self.assertFalse(resource("modules/amplify", "aws_route53_record", "certificate")["allow_overwrite"])
        self.assertFalse(resource("modules/amplify", "aws_route53_record", "frontend")["allow_overwrite"])

    def test_storage_logging_count_does_not_depend_on_computed_bucket_id(self):
        logging = resource("modules/storage", "aws_s3_bucket_logging", "this")
        self.assertIn("var.enable_access_logging", logging["count"])
        self.assertNotIn("var.access_log_bucket", logging["count"])

    def test_terraform_provider_required_sources_consistent(self):
        for directory in [*TF_ROOTS, *(ROOT / "modules").iterdir()]:
            version = hcl2.loads((directory / "versions.tf").read_text())["terraform"][0]
            self.assertEqual(version["required_providers"][0]["aws"]["source"], "hashicorp/aws")
            self.assertEqual(version["required_providers"][0]["aws"]["version"], "= 6.11.0")


class WorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        installed = ROOT / ".github/workflows/infrastructure.yml"
        cls.workflow_path = installed if installed.is_file() else ROOT / "infrastructure.yml"
        cls.workflow = yaml.safe_load(cls.workflow_path.read_text())

    def test_workflow_template_and_installed_copy_cannot_diverge(self):
        installed = ROOT / ".github/workflows/infrastructure.yml"
        template = ROOT / "infrastructure.yml"
        self.assertTrue(installed.is_file() or template.is_file())
        if installed.is_file() and template.is_file():
            self.assertEqual(installed.read_bytes(), template.read_bytes())

    def test_only_pushes_dev_prod_or_pr_events(self):
        triggers = self.workflow.get("on", self.workflow.get(True))
        self.assertEqual(set(triggers), {"pull_request", "push"})
        self.assertEqual(set(triggers["push"]["branches"]), {"dev", "prod"})
        self.assertEqual(self.workflow["permissions"], {"contents": "read"})

    def test_all_scans_are_required_and_apply_only_depends_on_aggregate(self):
        jobs = self.workflow["jobs"]
        self.assertEqual(set(jobs["checks"]["needs"]), {"unit", "terraform", "checkov", "trivy", "sonar"})
        self.assertEqual(jobs["deploy"]["needs"], "checks")
        self.assertIn("github.event_name == 'push'", jobs["deploy"]["if"])
        self.assertIn("refs/heads/dev", jobs["deploy"]["if"])
        self.assertIn("refs/heads/prod", jobs["deploy"]["if"])
        self.assertEqual(jobs["deploy"]["environment"]["name"], "${{ github.ref_name }}")
        self.assertIn("pull_request.head.repo.full_name == github.repository", jobs["sonar"]["if"])

    def test_no_aws_credentials_or_write_tokens_on_pr_jobs(self):
        for name, job in self.workflow["jobs"].items():
            self.assertNotIn("continue-on-error", job)
            if name != "deploy":
                self.assertNotEqual(job.get("permissions", {}).get("id-token"), "write")
                for step in job.get("steps", []):
                    self.assertNotIn("aws-actions/configure-aws-credentials", step.get("uses", ""))
                    self.assertNotIn("terraform apply", step.get("run", ""))
                    self.assertNotIn("continue-on-error", step)

    def test_actions_sha_pinned_and_checkout_credentials_not_persisted(self):
        for job in self.workflow["jobs"].values():
            for step in job.get("steps", []):
                if "uses" in step:
                    self.assertRegex(step["uses"], r"^[^@]+@[a-f0-9]{40}$")
                if step.get("uses", "").startswith("actions/checkout@"):
                    self.assertFalse(step["with"]["persist-credentials"])

    def test_saved_plan_is_applied_in_same_job_and_not_uploaded(self):
        steps = self.workflow["jobs"]["deploy"]["steps"]
        text = "\n".join(step.get("run", "") for step in steps)
        self.assertIn('plan -no-color -lock-timeout=10m -out="$plan"', text)
        self.assertIn('apply -no-color -lock-timeout=10m "$plan"', text)
        self.assertIn('verify_plan.py "$json_plan"', text)
        self.assertIn('workspace show)" = default', text)
        self.assertFalse(any("upload-artifact" in step.get("uses", "") for step in steps))
        self.assertFalse(self.workflow["concurrency"]["cancel-in-progress"])

    def test_sonar_is_mandatory_and_scans_fail_closed(self):
        text = self.workflow_path.read_text()
        self.assertIn("-Dsonar.qualitygate.wait=true", text)
        self.assertIn('.result == "success"', text)
        cfg = yaml.safe_load((ROOT / ".checkov.yaml").read_text())
        self.assertNotIn("soft-fail", cfg)
        self.assertNotIn("check", cfg)
        self.assertNotIn("skip-check", cfg)
        trivy = yaml.safe_load((ROOT / "trivy.yaml").read_text())
        self.assertEqual(trivy["exit-code"], 1)
        exceptions = yaml.safe_load((ROOT / ".trivyignore.yaml").read_text())
        self.assertEqual(set(exceptions), {"misconfigurations"})
        for exception in exceptions["misconfigurations"]:
            self.assertTrue(exception["paths"] and exception["statement"])
            self.assertGreaterEqual(exception["expired_at"], date(2026, 9, 7))

    def test_readme_and_runbooks_exist(self):
        for name in ("README.md", "docs/security.md", "docs/dns.md", "docs/operations.md", "docs/github-actions.md"):
            self.assertTrue((ROOT / name).is_file(), name)
