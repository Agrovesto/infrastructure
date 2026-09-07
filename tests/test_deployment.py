import contextlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts.ci import verify_plan, write_deploy_config, verify_checkov_report


def ci_env(environment="dev"):
    account = "111111111111" if environment == "dev" else "222222222222"
    peer = "222222222222" if environment == "dev" else "111111111111"
    return {
        "DEPLOY_ENV": environment, "GITHUB_EVENT_NAME": "push", "GITHUB_REF": f"refs/heads/{environment}",
        "AWS_ACCOUNT_ID": account, "AWS_REGION": "eu-west-1",
        "AWS_ROLE_ARN": f"arn:aws:iam::{account}:role/agrovesto-bootstrap-{environment}-deploy",
        "TF_STATE_BUCKET": f"agrovesto-tfstate-{account}-eu-west-1",
        "TF_STATE_KMS_KEY_ARN": f"arn:aws:kms:eu-west-1:{account}:key/11111111-1111-1111-1111-111111111111",
        "TF_VARS_JSON": json.dumps({"account_id": account, "peer_account_id": peer,
                                    "permissions_boundary_arn": f"arn:aws:iam::{account}:policy/agrovesto-bootstrap-{environment}-workload-boundary"}),
    }


class AccountIsolationTests(unittest.TestCase):
    def test_backend_key_is_hard_bound_to_environment_and_encrypted(self):
        for env in ("dev", "prod"):
            target, values, backend = write_deploy_config.configuration(ci_env(env))
            self.assertEqual(target, env)
            self.assertIn(f'key = "{env}/terraform.tfstate"', backend)
            self.assertIn("use_lockfile = true", backend)
            self.assertIn("encrypt = true", backend)
            self.assertIn("allowed_account_ids", backend)
            self.assertEqual(values["aws_region"], "eu-west-1")

    def test_events_and_refs_cannot_cross_environment_boundaries(self):
        for changes in [
            {"DEPLOY_ENV": "staging"}, {"GITHUB_EVENT_NAME": "pull_request"}, {"GITHUB_EVENT_NAME": "workflow_dispatch"},
            {"GITHUB_EVENT_NAME": "workflow_run"}, {"GITHUB_REF": "refs/heads/prod"},
            {"GITHUB_REF": "refs/tags/dev"}, {"GITHUB_REF": "refs/heads/dev-malicious"},
        ]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                write_deploy_config.configuration(dict(ci_env(), **changes))

    def test_invalid_or_cross_account_configuration_rejected(self):
        for changes in [
            {"AWS_ACCOUNT_ID": "123"}, {"AWS_REGION": "region\nkey=evil"}, {"TF_VARS_JSON": "[]"},
            {"AWS_ACCOUNT_ID": "222222222222"}, {"AWS_ROLE_ARN": "arn:aws:iam::222222222222:role/prod"},
            {"TF_STATE_BUCKET": "agrovesto-tfstate-222222222222-eu-west-1"},
            {"TF_STATE_KMS_KEY_ARN": "arn:aws:kms:eu-west-1:222222222222:key/11111111-1111-1111-1111-111111111111"},
        ]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                write_deploy_config.configuration(dict(ci_env(), **changes))
        for changes in [{"peer_account_id": "111111111111"}, {"peer_account_id": "bad"}, {"aws_region": "us-east-1"}, {"project": "bad\nname"}, {"permissions_boundary_arn": "wrong"}]:
            env = ci_env()
            values = dict(json.loads(env["TF_VARS_JSON"]), **changes)
            env["TF_VARS_JSON"] = json.dumps(values)
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                write_deploy_config.configuration(env)

    def test_writes_private_config_without_printing_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "environments/dev").mkdir(parents=True)
            env = dict(ci_env(), GITHUB_WORKSPACE=tmp, RUNNER_TEMP=tmp, GITHUB_OUTPUT=tmp + "/output")
            with patch.dict(os.environ, env), contextlib.redirect_stdout(io.StringIO()) as output:
                write_deploy_config.main()
            self.assertNotIn(env["TF_VARS_JSON"], output.getvalue())
            self.assertEqual(Path(tmp, "backend-dev.hcl").stat().st_mode & 0o777, 0o600)
            self.assertEqual(Path(tmp, "environments/dev/ci.auto.tfvars.json").stat().st_mode & 0o777, 0o600)
            self.assertIn("root=", Path(tmp, "output").read_text())
        with tempfile.TemporaryDirectory() as tmp, self.assertRaises(ValueError):
            write_deploy_config.write_files(dict(ci_env(), GITHUB_WORKSPACE=tmp, RUNNER_TEMP=tmp))


def planned(kind, values, address=None):
    return {"planned_values": {"root_module": {"child_modules": [{"resources": [{"type": kind, "values": values, "address": address or f"module.test.{kind}.this"}]}]}}}


class PlanGuardTests(unittest.TestCase):
    def test_refuses_all_protected_deletions_and_replacements(self):
        for kind in verify_plan.PROTECTED:
            for actions in [["delete"], ["delete", "create"], ["create", "delete"]]:
                p = {"resource_changes": [{"type": kind, "address": kind + ".test", "change": {"actions": actions}}]}
                self.assertTrue(verify_plan.violations(p))
        self.assertEqual(verify_plan.violations({"resource_changes": [{"type": "aws_ecs_service", "address": "api", "change": {"actions": ["update"]}}]}), [])

    def test_failed_plans_are_rejected(self):
        self.assertTrue(verify_plan.violations({"errored": True}))
        self.assertTrue(verify_plan.violations({"applyable": False}))

    def test_unsafe_rds_settings_rejected(self):
        for field, value in {"engine": "mysql", "license_model": "bring-your-own-license", "publicly_accessible": True,
                             "storage_encrypted": False, "deletion_protection": False,
                             "manage_master_user_password": False, "skip_final_snapshot": True}.items():
            with self.subTest(field=field):
                self.assertTrue(verify_plan.violations(planned("aws_db_instance", {field: value})))
        # multi_az is fixed off in this baseline; plan guard does not require it true.
        self.assertEqual(verify_plan.violations(planned("aws_db_instance", {"multi_az": False})), [])
        self.assertEqual(verify_plan.violations(planned("aws_db_instance", {"engine": "sqlserver-se", "kms_key_id": None})), [])

    def test_unsafe_ec2_and_disk_settings_rejected(self):
        for values in [{"associate_public_ip_address": True}, {"metadata_options": [{"http_tokens": "optional"}]}, {"root_block_device": [{"encrypted": False}]}]:
            self.assertTrue(verify_plan.violations(planned("aws_instance", values)))
        self.assertTrue(verify_plan.violations(planned("aws_ebs_volume", {"encrypted": False})))

    def test_ecs_security_settings_rejected(self):
        self.assertTrue(verify_plan.violations(planned("aws_ecs_service", {"network_configuration": [{"assign_public_ip": True}]})))
        safe = {"readonlyRootFilesystem": True, "user": "10001:10001"}
        self.assertFalse(verify_plan.violations(planned("aws_ecs_task_definition", {"container_definitions": json.dumps([safe])})))
        for unsafe in [{"privileged": True}, {"readonlyRootFilesystem": False}, {"user": "0"}, {"user": "root"}, {"environment": [{"name": "DB_PASSWORD", "value": "not-allowed"}]}]:
            self.assertTrue(verify_plan.violations(planned("aws_ecs_task_definition", {"container_definitions": json.dumps([dict(safe, **unsafe)])})))
        self.assertEqual(verify_plan.violations(planned("aws_ecs_task_definition", {"container_definitions": None})), [])

    def test_only_edge_http_redirect_and_https_public_ingress_allowed(self):
        for port in (80, 443):
            values = {"cidr_ipv4": "0.0.0.0/0", "ip_protocol": "tcp", "from_port": port, "to_port": port}
            self.assertEqual(verify_plan.violations(planned("aws_vpc_security_group_ingress_rule", values, "module.edge.aws_vpc_security_group_ingress_rule.test")), [])
            self.assertTrue(verify_plan.violations(planned("aws_vpc_security_group_ingress_rule", values)))
        for port in (22, 1433, 8080):
            values = {"cidr_ipv6": "::/0", "ip_protocol": "tcp", "from_port": port, "to_port": port}
            self.assertTrue(verify_plan.violations(planned("aws_vpc_security_group_ingress_rule", values, "module.edge.aws_vpc_security_group_ingress_rule.bad")))

    def test_data_sources_are_not_treated_as_managed_resources(self):
        p = planned("aws_db_instance", {"engine": "mysql"})
        p["planned_values"]["root_module"]["child_modules"][0]["resources"][0]["mode"] = "data"
        self.assertEqual(verify_plan.violations(p), [])

    def test_plan_cli_exit_code(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp, "plan.json")
            file.write_text("{}")
            with patch("sys.argv", ["verify_plan.py", str(file)]), contextlib.redirect_stdout(io.StringIO()):
                verify_plan.main()
            file.write_text('{"errored":true}')
            with patch("sys.argv", ["verify_plan.py", str(file)]), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
                verify_plan.main()
            self.assertEqual(error.exception.code, 1)


class ScannerReportTests(unittest.TestCase):
    def good(self):
        return [{"check_type": framework, "summary": {"passed": 2, "failed": 0, "skipped": 1, "parsing_errors": 0}}
                for framework in sorted(verify_checkov_report.FRAMEWORKS)]

    def test_nonempty_framework_results_required(self):
        self.assertEqual(verify_checkov_report.check_report(self.good())[1], [])
        self.assertTrue(verify_checkov_report.check_report({"passed": 0})[1])
        self.assertTrue(verify_checkov_report.check_report(self.good()[:2])[1])
        data = self.good()
        data[0]["summary"]["passed"] = 0
        self.assertTrue(verify_checkov_report.check_report(data)[1])

    def test_failures_and_parse_errors_fail_closed(self):
        data = self.good()
        data[0]["summary"]["failed"] = 1
        data[0]["results"] = {"failed_checks": [{"check_id": "CKV_FIXTURE", "resource": "fixture", "file_path": "fixture.tf"}]}
        errors = verify_checkov_report.check_report(data)[1]
        self.assertTrue(any("CKV_FIXTURE" in e for e in errors))
        data = self.good()
        data[0]["summary"]["parsing_errors"] = 1
        self.assertTrue(verify_checkov_report.check_report(data)[1])

    def test_cli_reports_success_and_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp, "report.json")
            file.write_text(json.dumps(self.good()))
            with patch("sys.argv", ["verify_checkov_report.py", str(file)]), contextlib.redirect_stdout(io.StringIO()):
                verify_checkov_report.main()
            file.write_text("{}")
            with patch("sys.argv", ["verify_checkov_report.py", str(file)]), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
                verify_checkov_report.main()
            self.assertEqual(error.exception.code, 1)

    def test_cli_combines_source_and_staged_workflow_reports(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp, "source.json")
            workflow = Path(tmp, "workflow.json")
            source.write_text(json.dumps([item for item in self.good() if item["check_type"] != "github_actions"]))
            workflow.write_text(json.dumps(next(item for item in self.good() if item["check_type"] == "github_actions")))
            with patch("sys.argv", ["verify_checkov_report.py", str(source), str(workflow)]), contextlib.redirect_stdout(io.StringIO()) as output:
                verify_checkov_report.main()
            self.assertIn("github_actions: 2 passed", output.getvalue())
