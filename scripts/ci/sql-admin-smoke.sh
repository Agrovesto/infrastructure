#!/usr/bin/env bash
set -Eeuo pipefail
image=${1:?Usage: sql-admin-smoke.sh IMAGE}
# Exercise the same non-root/read-only constraints as the one-shot ECS task.
# No AWS credentials, network, database server or secrets are needed.
docker run --rm --network none --read-only --cap-drop ALL \
  --security-opt no-new-privileges \
  --entrypoint python "$image" -c '
import ctypes
from pathlib import Path
import os
import ssl
import subprocess
import sys

import boto3

assert sys.version_info[:2] == (3, 12)
assert os.geteuid() == 10001 and os.getegid() == 10001
assert boto3.__version__
driver, = Path("/opt/microsoft/msodbcsql18/lib64").glob("libmsodbcsql-*.so.*")
ctypes.CDLL(str(driver))
certificates = list(Path("/usr/local/share/ca-certificates").glob("rds-*.crt"))
assert certificates, "RDS CA certificates were not installed"
context = ssl.create_default_context()
trusted = {ssl.DER_cert_to_PEM_cert(cert).strip() for cert in context.get_ca_certs(binary_form=True)}
assert all(cert.read_text().strip() in trusted for cert in certificates), "RDS CAs missing from trust store"
subprocess.run(["/opt/mssql-tools18/bin/sqlcmd", "-?"], check=True)
subprocess.run([sys.executable, "/app/database.py", "--help"], check=True)
print("SQL admin runtime smoke test passed; no live SQL connection was attempted.")