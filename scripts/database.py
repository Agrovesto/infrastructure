#!/usr/bin/env python3
"""Private SQL Server administration. Secret values never pass through Terraform.

The same program runs on dev EC2 (sqlcmd via docker exec) and as a one-off
production ECS task (local sqlcmd, verified TLS to RDS). No destructive SQL is
issued. See docs/operations.md for bootstrap, credential changes and restoration.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from uuid import uuid4

import boto3
from botocore.exceptions import ClientError

IDENTIFIER = re.compile(r"^[A-Za-z][A-Za-z0-9_]{0,62}$")
ENV_NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
SYSTEM_DATABASES = {"master", "model", "msdb", "tempdb", "rdsadmin"}


def identifier(value: str) -> str:
    if not isinstance(value, str) or not IDENTIFIER.fullmatch(value):
        raise ValueError("Invalid SQL identifier")
    return f"[{value}]"


def literal(value: str) -> str:
    if not isinstance(value, str) or any(ord(c) < 32 or ord(c) == 127 for c in value):
        raise ValueError("Invalid SQL string")
    return "N'" + value.replace("'", "''") + "'"


def validate_config(config: dict) -> dict:
    if config.get("environment") not in {"dev", "prod"}:
        raise ValueError("Environment must be dev or prod")
    seen = set()
    for key, spec in config["databases"].items():
        if not re.fullmatch(r"[a-z][a-z0-9_]{0,29}", key):
            raise ValueError("Invalid database key")
        identifier(spec["name"])
        if spec["name"].lower() in seen | SYSTEM_DATABASES:
            raise ValueError("Database names must be unique and not system databases")
        seen.add(spec["name"].lower())
        if not spec["secret_arn"].startswith("arn:aws:secretsmanager:"):
            raise ValueError("Expected a Secrets Manager ARN")
    if config["environment"] == "prod" and config.get("sql_container"):
        raise ValueError("Production must use verified RDS TLS, not a dev container")
    return config


def load_config(path: str | None) -> dict:
    raw = Path(path).read_text() if path else os.environ["DB_CONFIG"]
    return validate_config(json.loads(raw))


def read_secret(client, arn: str) -> dict:
    return json.loads(client.get_secret_value(SecretId=arn)["SecretString"])


def ensure_credentials(client, arn: str, username: str, *, database: str | None = None,
                       allow_create: bool = True) -> dict:
    try:
        value = read_secret(client, arn)
    except ClientError as exc:
        if exc.response["Error"]["Code"] != "ResourceNotFoundException" or not allow_create:
            raise
        # Missing secret VERSION is expected on first bootstrap; the metadata
        # must already exist. Do not accidentally create a secret in a wrong account.
        client.describe_secret(SecretId=arn)
        password = client.get_random_password(
            PasswordLength=40, RequireEachIncludedType=True,
            ExcludeCharacters="'\"\\`$\n\r",
        )["RandomPassword"]
        value = {"username": username, "password": password}
        if database:
            value["database"] = database
        client.put_secret_value(SecretId=arn, SecretString=json.dumps(value))
    if value.get("username") != username or not isinstance(value.get("password"), str):
        raise ValueError("Secret must contain the expected username and a password")
    if database and value.get("database") != database:
        raise ValueError("Database name changes require an explicit migration, not renaming a secret")
    return value


def write_env(path: Path, values: dict) -> None:
    """Compose raw env files on /run (tmpfs), root-only, with atomic replacement."""
    lines = []
    for key, value in sorted(values.items()):
        if not ENV_NAME.fullmatch(key) or not isinstance(value, str):
            raise ValueError("Environment entries must be named strings")
        if any(c in value for c in "\n\r\x00"):
            raise ValueError("Multiline secret values require mounted files, not env files")
        lines.append(f"{key}={value}\n")
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temp_path = tempfile.mkstemp(dir=path.parent, prefix=".secret-")
    try:
        with os.fdopen(fd, "w") as handle:
            handle.writelines(lines)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temp_path, 0o600)
        os.replace(temp_path, path)
    finally:
        if os.path.exists(temp_path):
            os.unlink(temp_path)


class SqlRunner:
    def __init__(self, config: dict, credentials: dict):
        self.password = credentials["password"]
        self.command = []
        if config.get("sql_container"):
            self.command = ["docker", "exec", "-i", "-e", "SQLCMDPASSWORD", "-e", "SQLCMDINI=", config["sql_container"]]
        self.command += ["/opt/mssql-tools18/bin/sqlcmd", "-S",
                         "localhost,1433" if config.get("sql_container") else f"{config['db_host']},1433",
                         "-U", credentials["username"], "-N", "-b", "-r", "1", "-l", "30", "-x"]
        # Developer SQL Server has a self-signed certificate. Production NEVER uses -C.
        if config["environment"] == "dev":
            self.command.append("-C")

    def execute(self, sql: str, timeout: int = 300) -> None:
        env = dict(os.environ, SQLCMDPASSWORD=self.password)
        # -X disables environment imports (including credential delivery on some
        # sqlcmd versions). Instead remove startup scripts explicitly, disable
        # variable expansion with -x, and reject control characters in literals.
        env.pop("SQLCMDINI", None)
        result = subprocess.run(self.command, input=sql, text=True, env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                timeout=timeout, check=False)
        if result.returncode:
            # sqlcmd output can echo SQL containing credentials. Do not print it.
            raise RuntimeError("SQL command failed; inspect server error logs (SQL text suppressed)")

    def wait(self, attempts: int = 90) -> None:
        for attempt in range(attempts):
            try:
                self.execute("SET NOCOUNT ON; SELECT 1;", timeout=40)
                return
            except (RuntimeError, subprocess.TimeoutExpired):
                if attempt == attempts - 1:
                    raise
                time.sleep(5)


def provisioning_sql(database: str, username: str, password: str, sync_password: bool = False) -> str:
    if database.lower() in SYSTEM_DATABASES:
        raise ValueError("Refusing system database provisioning")
    db, user = identifier(database), identifier(username)
    password_sql = literal(password)
    # -x in sqlcmd disables $(variable) substitution in arbitrary secret values.
    statements = [
        f"IF DB_ID({literal(database)}) IS NULL CREATE DATABASE {db};\nGO",
        f"IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name={literal(username)})\n"
        f"  CREATE LOGIN {user} WITH PASSWORD={password_sql}, CHECK_POLICY=ON, CHECK_EXPIRATION=OFF;\nGO",
    ]
    if sync_password:
        statements.append(f"ALTER LOGIN {user} WITH PASSWORD={password_sql};\nGO")
    statements += [
        f"USE {db};\nGO",
        f"IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name={literal(username)})\n"
        f"  CREATE USER {user} FOR LOGIN {user};\nGO",
        f"ALTER USER {user} WITH LOGIN={user};\nGO",
        f"IF IS_ROLEMEMBER('db_datareader', {literal(username)}) <> 1 ALTER ROLE db_datareader ADD MEMBER {user};",
        f"IF IS_ROLEMEMBER('db_datawriter', {literal(username)}) <> 1 ALTER ROLE db_datawriter ADD MEMBER {user};",
        f"GRANT EXECUTE TO {user};\nGO",
    ]
    return "\n".join(statements)


def prepare_dev(config: dict, secrets_client) -> None:
    if config["environment"] != "dev":
        raise ValueError("Dev-only operation")
    root = Path(config.get("data_mount", "/srv/mssql"))
    if not os.path.ismount(root):
        raise RuntimeError("The SQL data disk is not mounted; refusing to write to the OS disk")
    # On a recovered disk a lost admin secret must be recovered, NOT regenerated.
    admin = ensure_credentials(secrets_client, config["admin_secret_arn"], "sa",
                               allow_create=not (root / "data/master.mdf").exists())
    write_env(Path(config.get("env_dir", "/run/agrovesto")) / "sql.env", {
        "MSSQL_SA_PASSWORD": admin["password"], "SQLCMDPASSWORD": admin["password"],
    })


def provision(config: dict, secrets_client, runner: SqlRunner, sync_passwords: bool = False) -> None:
    runner.wait()
    for key, spec in config["databases"].items():
        credential = ensure_credentials(secrets_client, spec["secret_arn"], f"app_{key}", database=spec["name"])
        runner.execute(provisioning_sql(spec["name"], credential["username"], credential["password"], sync_passwords))
        print(f"Provisioned database and runtime login: {key}", flush=True)


def secret_value(client, reference: str) -> str:
    parts = reference.split(":")
    if len(parts) < 7 or parts[2] != "secretsmanager" or len(parts) > 10:
        raise ValueError("Invalid Secrets Manager reference")
    args = {"SecretId": ":".join(parts[:7])}
    if len(parts) > 8 and parts[8]:
        args["VersionStage"] = parts[8]
    if len(parts) > 9 and parts[9]:
        args["VersionId"] = parts[9]
    value = client.get_secret_value(**args)["SecretString"]
    if len(parts) > 7 and parts[7]:
        value = json.loads(value)[parts[7]]
    if not isinstance(value, str):
        raise ValueError("Only string secrets can be used as environment variables")
    return value


def render_dev_env(config: dict, secrets_client) -> None:
    if config["environment"] != "dev":
        raise ValueError("Dev-only operation")
    directory = Path(config.get("env_dir", "/run/agrovesto"))
    for name, service in config.get("services", {}).items():
        env = {key: secret_value(secrets_client, arn) for key, arn in service.get("secrets", {}).items()}
        db_key = service.get("database_key")
        if db_key:
            db = config["databases"][db_key]
            credentials = read_secret(secrets_client, db["secret_arn"])
            env.update(DB_HOST="mssql", DB_PORT="1433", DB_NAME=db["name"],
                       DB_USER=credentials["username"], DB_PASSWORD=credentials["password"],
                       DB_ENCRYPT="true", DB_TRUST_SERVER_CERTIFICATE="true")
        write_env(directory / f"{name}.env", env)


def backup_sql(database: str, container_path: str) -> str:
    return (
        f"BACKUP DATABASE {identifier(database)} TO DISK={literal(container_path)} "
        "WITH COPY_ONLY, COMPRESSION, CHECKSUM, INIT;\nGO\n"
        f"RESTORE VERIFYONLY FROM DISK={literal(container_path)} WITH CHECKSUM;\nGO\n"
    )


def run_backup(config: dict, runner: SqlRunner, s3, cloudwatch) -> None:
    if config["environment"] != "dev" or not os.path.ismount(config.get("data_mount", "/srv/mssql")):
        raise RuntimeError("Native disk backup is dev-only and requires the mounted DB volume")
    successful = False
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid4().hex[:8]
    prefix = f"sqlserver/{timestamp}"
    manifest = {"timestamp": timestamp, "databases": []}
    try:
        runner.wait()
        for key, spec in config["databases"].items():
            filename = f"{spec['name']}.bak"
            local_file = Path(config.get("data_mount", "/srv/mssql")) / "backup" / f"{timestamp}-{filename}"
            container_file = f"/var/opt/mssql/backup/{local_file.name}"
            runner.execute(backup_sql(spec["name"], container_file), timeout=7200)
            digest = hashlib.sha256()
            with local_file.open("rb") as handle:
                for block in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(block)
            object_key = f"{prefix}/{filename}"
            s3.upload_file(str(local_file), config["backup_bucket"], object_key, ExtraArgs={
                "ServerSideEncryption": "aws:kms", "SSEKMSKeyId": config["kms_key_arn"],
                "ChecksumAlgorithm": "SHA256",
            })
            manifest["databases"].append({"key": key, "name": spec["name"], "object_key": object_key,
                                           "sha256": digest.hexdigest(), "size_bytes": local_file.stat().st_size})
            local_file.unlink()  # A failed upload intentionally retains the local .bak.
        s3.put_object(Bucket=config["backup_bucket"], Key=f"{prefix}/manifest.json",
                      Body=json.dumps(manifest).encode(), ContentType="application/json",
                      ServerSideEncryption="aws:kms", SSEKMSKeyId=config["kms_key_arn"])
        successful = True
        print(f"Verified native backups uploaded: {prefix}", flush=True)
    finally:
        # No heartbeat (including a stopped EC2 host) is also an alarm condition.
        cloudwatch.put_metric_data(Namespace=f"{config['project']}/Backups", MetricData=[{
            "MetricName": "DatabaseBackupSuccess", "Value": int(successful), "Unit": "Count",
            "Dimensions": [{"Name": "Environment", "Value": "dev"}],
        }])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prepare-dev", "provision", "render-dev-env", "backup"])
    parser.add_argument("--config", help="Runtime JSON file; otherwise read DB_CONFIG")
    parser.add_argument("--sync-passwords", action="store_true", help="Explicitly reconcile existing login passwords after a controlled rotation/restore")
    args = parser.parse_args()
    config = load_config(args.config)
    session = boto3.Session(region_name=config["region"])
    secrets_client = session.client("secretsmanager")
    if args.command == "prepare-dev":
        prepare_dev(config, secrets_client)
    elif args.command == "render-dev-env":
        render_dev_env(config, secrets_client)
    else:
        runner = SqlRunner(config, read_secret(secrets_client, config["admin_secret_arn"]))
        if args.command == "provision":
            provision(config, secrets_client, runner, args.sync_passwords)
        else:
            run_backup(config, runner, session.client("s3"), session.client("cloudwatch"))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        # Do not log repr(error), subprocess input, connection strings or secret values.
        print(f"Database operation failed ({type(error).__name__}). No secret or SQL text was logged.", file=sys.stderr)
        sys.exit(1)
