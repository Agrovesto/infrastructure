import contextlib
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

from botocore.exceptions import ClientError
from scripts import database as db

ADMIN = "arn:aws:secretsmanager:eu-west-1:353833416626:secret:admin-AbCdEf"
APP = "arn:aws:secretsmanager:eu-west-1:353833416626:secret:api-AbCdEf"
PASSWORD = "Fixture-Only-Aa1!not-a-real-credential"


def config(environment="dev"):
    value = {
        "environment": environment, "region": "eu-west-1", "project": "agrovesto",
        "db_host": "private.example.com", "admin_secret_arn": ADMIN,
        "databases": {"api": {"name": "AgrovestoApi", "secret_arn": APP}},
        "services": {"api": {"database_key": "api", "secrets": {}}},
        "backup_bucket": "fixture-backups", "kms_key_arn": "arn:aws:kms:eu-west-1:353833416626:key/fixture",
    }
    if environment == "dev":
        value["sql_container"] = "agrovesto-dev-mssql"
    return value


def credentials(username="sa", database=None):
    result = {"username": username, "password": PASSWORD}
    if database:
        result["database"] = database
    return result


def missing(code="ResourceNotFoundException"):
    return ClientError({"Error": {"Code": code, "Message": "Fixture"}}, "GetSecretValue")


class SqlSafetyTests(unittest.TestCase):
    def test_identifiers_are_validated(self):
        self.assertEqual(db.identifier("Api_2"), "[Api_2]")
        for invalid in ("Api]; DROP DATABASE x;--", "two words", "", "2name", "x" * 64, None):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                db.identifier(invalid)

    def test_sql_literals_escape_quotes_and_reject_batch_injection(self):
        self.assertEqual(db.literal("a'b$(value)"), "N'a''b$(value)'")
        for invalid in (None, "x\x00", "secret\nGO\n!! bad", "x\r", "x\x7f"):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                db.literal(invalid)

    def test_config_safety(self):
        self.assertEqual(db.validate_config(config()), config())
        for changes in [
            {"environment": "staging"},
            {"databases": {"api": {"name": "master", "secret_arn": APP}}},
            {"databases": {"BAD-KEY": {"name": "Api", "secret_arn": APP}}},
            {"databases": {"api": {"name": "Api", "secret_arn": "not-an-arn"}}},
            {"databases": {"a": {"name": "Api", "secret_arn": APP}, "b": {"name": "api", "secret_arn": APP}}},
            {"environment": "prod", "sql_container": "dev"},
        ]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                db.validate_config(dict(config(), **changes))

    def test_load_file_and_environment(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / "runtime.json"
            file.write_text(json.dumps(config()))
            self.assertEqual(db.load_config(str(file)), config())
        with patch.dict(os.environ, {"DB_CONFIG": json.dumps(config("prod"))}):
            self.assertEqual(db.load_config(None), config("prod"))

    def test_provision_sql_has_idempotency_and_no_db_owner(self):
        sql = db.provisioning_sql("Api", "app_api", "a'b")
        self.assertIn("IF DB_ID(N'Api') IS NULL CREATE DATABASE [Api]", sql)
        self.assertIn("PASSWORD=N'a''b'", sql)
        self.assertIn("ALTER USER [app_api] WITH LOGIN=[app_api]", sql)
        self.assertIn("db_datareader", sql)
        self.assertIn("db_datawriter", sql)
        self.assertIn("GRANT EXECUTE", sql)
        self.assertNotIn("db_owner", sql)
        self.assertNotIn("ALTER LOGIN", sql)
        self.assertIn("ALTER LOGIN", db.provisioning_sql("Api", "app_api", PASSWORD, True))
        with self.assertRaises(ValueError):
            db.provisioning_sql("master", "app_api", PASSWORD)

    def test_backup_sql_is_native_consistent_and_verified(self):
        sql = db.backup_sql("Api", "/var/opt/mssql/backup/api.bak")
        self.assertIn("COPY_ONLY, COMPRESSION, CHECKSUM", sql)
        self.assertIn("RESTORE VERIFYONLY", sql)
        self.assertNotIn("STOP", sql)
        with self.assertRaises(ValueError):
            db.backup_sql("Api];--", "anything")

    def test_production_requires_verified_tls_and_hides_password(self):
        runner = db.SqlRunner(config("prod"), credentials("platform_admin"))
        self.assertIn("-N", runner.command)
        self.assertIn("-x", runner.command)
        self.assertNotIn("-X1", runner.command)
        self.assertNotIn("-C", runner.command)
        self.assertNotIn("-P", runner.command)
        self.assertNotIn(PASSWORD, runner.command)
        with patch.dict(os.environ, {"SQLCMDINI": "/untrusted-startup.sql"}), patch.object(db.subprocess, "run", return_value=Mock(returncode=0)) as run:
            runner.execute("SELECT 1")
        self.assertEqual(run.call_args.kwargs["env"]["SQLCMDPASSWORD"], PASSWORD)
        self.assertEqual(run.call_args.kwargs["input"], "SELECT 1")
        self.assertNotIn("SQLCMDINI", run.call_args.kwargs["env"])
        self.assertTrue(run.call_args.kwargs["stdout"] == subprocess.PIPE)

    def test_dev_exec_passes_password_by_environment_not_cli(self):
        runner = db.SqlRunner(config(), credentials())
        self.assertIn("-C", runner.command)
        self.assertEqual(runner.command[:8], ["docker", "exec", "-i", "-e", "SQLCMDPASSWORD", "-e", "SQLCMDINI=", "agrovesto-dev-mssql"])
        self.assertNotIn(PASSWORD, runner.command)

    def test_sql_failure_does_not_echo_sql_or_password(self):
        runner = db.SqlRunner(config(), credentials())
        with patch.object(db.subprocess, "run", return_value=Mock(returncode=1, stdout=PASSWORD, stderr=PASSWORD)):
            with self.assertRaises(RuntimeError) as error:
                runner.execute(f"SELECT '{PASSWORD}'")
        self.assertNotIn(PASSWORD, str(error.exception))

    def test_wait_retries_and_times_out(self):
        runner = db.SqlRunner(config(), credentials())
        with patch.object(runner, "execute", side_effect=[RuntimeError("not ready"), None]) as execute, patch.object(db.time, "sleep"):
            runner.wait(attempts=2)
            self.assertEqual(execute.call_count, 2)
        with patch.object(runner, "execute", side_effect=subprocess.TimeoutExpired("sqlcmd", 40)), patch.object(db.time, "sleep"):
            with self.assertRaises(subprocess.TimeoutExpired):
                runner.wait(attempts=2)


class SecretTests(unittest.TestCase):
    def test_existing_credentials_are_not_replaced(self):
        client = Mock()
        client.get_secret_value.return_value = {"SecretString": json.dumps(credentials())}
        self.assertEqual(db.ensure_credentials(client, ADMIN, "sa"), credentials())
        client.put_secret_value.assert_not_called()
        client.get_random_password.assert_not_called()

    def test_missing_value_generated_only_when_metadata_exists(self):
        client = Mock()
        client.get_secret_value.side_effect = missing()
        client.get_random_password.return_value = {"RandomPassword": PASSWORD}
        value = db.ensure_credentials(client, APP, "app_api", database="AgrovestoApi")
        self.assertEqual(value, credentials("app_api", "AgrovestoApi"))
        client.describe_secret.assert_called_once_with(SecretId=APP)
        self.assertEqual(json.loads(client.put_secret_value.call_args.kwargs["SecretString"]), value)
        self.assertTrue(client.get_random_password.call_args.kwargs["RequireEachIncludedType"])

    def test_missing_metadata_not_silently_created(self):
        client = Mock()
        client.get_secret_value.side_effect = missing()
        client.describe_secret.side_effect = missing()
        with self.assertRaises(ClientError):
            db.ensure_credentials(client, ADMIN, "sa")
        client.put_secret_value.assert_not_called()

    def test_access_denied_and_restored_disk_do_not_generate_credentials(self):
        for error, allow_create in [(missing("AccessDeniedException"), True), (missing(), False)]:
            client = Mock()
            client.get_secret_value.side_effect = error
            with self.assertRaises(ClientError):
                db.ensure_credentials(client, ADMIN, "sa", allow_create=allow_create)
            client.put_secret_value.assert_not_called()

    def test_secret_schema_and_renames_are_checked(self):
        for value in [credentials("wrong"), {"username": "app_api", "password": 123}, credentials("app_api", "OldDatabase")]:
            client = Mock()
            client.get_secret_value.return_value = {"SecretString": json.dumps(value)}
            with self.assertRaises(ValueError):
                db.ensure_credentials(client, APP, "app_api", database="NewDatabase")

    def test_raw_env_is_atomic_private_and_not_interpolated(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / "secrets" / "api.env"
            db.write_env(file, {"PASSWORD": "$arbitrary'quoted!", "NAME": "api"})
            self.assertEqual(stat.S_IMODE(file.stat().st_mode), 0o600)
            self.assertEqual(file.read_text(), "NAME=api\nPASSWORD=$arbitrary'quoted!\n")
            self.assertEqual(len(list(file.parent.iterdir())), 1)
            for values in [{"BAD-NAME": "a"}, {"KEY": 123}, {"KEY": "x\nANOTHER=bad"}, {"KEY": "x\x00"}]:
                with self.assertRaises(ValueError):
                    db.write_env(file, values)
            self.assertEqual(file.read_text(), "NAME=api\nPASSWORD=$arbitrary'quoted!\n")

    def test_env_temporary_file_is_removed_on_failure(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(db.os, "replace", side_effect=OSError("fixture")):
            with self.assertRaises(OSError):
                db.write_env(Path(tmp) / "test.env", {"KEY": "value"})
            self.assertEqual(list(Path(tmp).iterdir()), [])

    def test_prepare_requires_dev_mounted_disk_and_preserves_admin(self):
        with self.assertRaises(ValueError):
            db.prepare_dev(config("prod"), Mock())
        with patch.object(db.os.path, "ismount", return_value=False):
            with self.assertRaises(RuntimeError):
                db.prepare_dev(config(), Mock())
        with tempfile.TemporaryDirectory() as tmp:
            cfg = dict(config(), data_mount=tmp, env_dir=tmp + "/env")
            Path(tmp, "data").mkdir()
            Path(tmp, "data/master.mdf").touch()
            with patch.object(db.os.path, "ismount", return_value=True), patch.object(db, "ensure_credentials", return_value=credentials()) as ensure:
                db.prepare_dev(cfg, Mock())
            self.assertFalse(ensure.call_args.kwargs["allow_create"])
            self.assertIn("MSSQL_SA_PASSWORD=", Path(tmp, "env/sql.env").read_text())
            self.assertIn("SQLCMDPASSWORD=", Path(tmp, "env/sql.env").read_text())

    def test_provision_waits_and_uses_one_login_per_database(self):
        runner = Mock()
        with patch.object(db, "ensure_credentials", return_value=credentials("app_api", "AgrovestoApi")), contextlib.redirect_stdout(io.StringIO()) as output:
            db.provision(config(), Mock(), runner)
        runner.wait.assert_called_once()
        self.assertIn("[AgrovestoApi]", runner.execute.call_args.args[0])
        self.assertNotIn(PASSWORD, output.getvalue())

    def test_ecs_style_secret_reference_selector(self):
        client = Mock()
        client.get_secret_value.return_value = {"SecretString": '{"key":"selected"}'}
        self.assertEqual(db.secret_value(client, APP + ":key:AWSPREVIOUS:"), "selected")
        client.get_secret_value.assert_called_with(SecretId=APP, VersionStage="AWSPREVIOUS")
        self.assertEqual(db.secret_value(client, APP + ":key::version"), "selected")
        client.get_secret_value.assert_called_with(SecretId=APP, VersionId="version")
        self.assertEqual(db.secret_value(client, APP), '{"key":"selected"}')
        for invalid in ("not-an-arn", "arn:aws:s3:::bucket", APP + ":a:b:c:d"):
            with self.assertRaises(ValueError):
                db.secret_value(client, invalid)
        client.get_secret_value.return_value = {"SecretString": '{"key":1}'}
        with self.assertRaises(ValueError):
            db.secret_value(client, APP + ":key::")

    def test_render_service_env_and_no_prod_env_files(self):
        with self.assertRaises(ValueError):
            db.render_dev_env(config("prod"), Mock())
        with tempfile.TemporaryDirectory() as tmp, patch.object(db, "read_secret", return_value=credentials("app_api")), patch.object(db, "secret_value", return_value="fixture-key"):
            cfg = dict(config(), env_dir=tmp)
            cfg["services"]["api"]["secrets"] = {"SIGNING_KEY": APP}
            cfg["services"]["stateless"] = {"secrets": {}}
            db.render_dev_env(cfg, Mock())
            text = Path(tmp, "api.env").read_text()
            self.assertIn("DB_HOST=mssql", text)
            self.assertIn("DB_TRUST_SERVER_CERTIFICATE=true", text)
            self.assertIn("SIGNING_KEY=fixture-key", text)
            self.assertEqual(Path(tmp, "stateless.env").read_text(), "")


class BackupTests(unittest.TestCase):
    def run_case(self, upload_fails=False):
        with tempfile.TemporaryDirectory() as tmp:
            cfg = dict(config(), data_mount=tmp)
            Path(tmp, "backup").mkdir()
            runner, s3, cw = Mock(), Mock(), Mock()
            runner.execute.side_effect = lambda *args, **kwargs: Path(tmp, "backup/20260907T023000Z-12345678-AgrovestoApi.bak").write_bytes(b"verified-native-backup")
            if upload_fails:
                s3.upload_file.side_effect = RuntimeError("upload failed")
            with patch.object(db.os.path, "ismount", return_value=True), patch.object(db, "datetime") as dt, patch.object(db, "uuid4") as uuid:
                dt.now.return_value.strftime.return_value = "20260907T023000Z"
                uuid.return_value.hex = "12345678abcdef"
                if upload_fails:
                    with self.assertRaises(RuntimeError):
                        db.run_backup(cfg, runner, s3, cw)
                else:
                    with contextlib.redirect_stdout(io.StringIO()):
                        db.run_backup(cfg, runner, s3, cw)
            metric = cw.put_metric_data.call_args.kwargs["MetricData"][0]
            self.assertEqual(metric["Value"], 0 if upload_fails else 1)
            self.assertEqual(len(list(Path(tmp, "backup").iterdir())), 1 if upload_fails else 0)
            if not upload_fails:
                manifest = json.loads(s3.put_object.call_args.kwargs["Body"])
                self.assertEqual(manifest["databases"][0]["name"], "AgrovestoApi")
                self.assertEqual(len(manifest["databases"][0]["sha256"]), 64)
                self.assertEqual(s3.upload_file.call_args.kwargs["ExtraArgs"]["ServerSideEncryption"], "aws:kms")
                self.assertEqual(s3.put_object.call_args.kwargs["ServerSideEncryption"], "aws:kms")
            else:
                s3.put_object.assert_not_called()

    def test_successful_backup_manifest_checksum_encryption_and_cleanup(self):
        self.run_case()

    def test_failed_upload_retains_local_backup_and_publishes_failure(self):
        self.run_case(upload_fails=True)

    def test_production_and_unmounted_disk_rejected(self):
        for cfg in [config(), config("prod")]:
            with patch.object(db.os.path, "ismount", return_value=False), self.assertRaises(RuntimeError):
                db.run_backup(cfg, Mock(), Mock(), Mock())


class EntryPointTests(unittest.TestCase):
    def test_all_commands_use_regional_runtime_aws_session(self):
        operations = {"prepare-dev": "prepare_dev", "render-dev-env": "render_dev_env", "provision": "provision", "backup": "run_backup"}
        for command, function in operations.items():
            with self.subTest(command=command), patch.object(db, "load_config", return_value=config()), patch.object(db.boto3, "Session") as session, patch.object(db, "read_secret", return_value=credentials()), patch.object(db, function) as operation, patch("sys.argv", ["database.py", command]):
                db.main()
                session.assert_called_once_with(region_name="eu-west-1")
                operation.assert_called_once()
