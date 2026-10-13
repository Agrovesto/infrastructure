#!/usr/bin/env python3
"""Collect SQL Server DMV metrics for Prometheus and Grafana.

One collector, two runtimes:

- prod (monitoring/rds.tf): a scheduled Fargate task runs this in one-shot
  mode and pushes to Pushgateway (job=mssql), which Prometheus scrapes and
  the database alert rules evaluate.
- dev (dev/docker-compose.yml.tftpl): the mssql-exporter container runs the
  same file in serve mode (SERVE_PORT set) and re-collects on every
  Prometheus scrape. dev/host_config ships this script from the repository
  path it lives at, so both stacks run exactly this code.

Connection details:
- with DB_SECRET_NAME set: username/password come from Secrets Manager
  (prod: the RDS-managed master secret), host/port from DB_HOST/DB_PORT.
- without it: DB_USER/DB_PASSWORD/DB_HOST/DB_PORT environment variables
  (dev: the SA account, already in the host's compose .env file).

The queries are SQL Server DMVs read over TDS with python-tds — the PyPI
distribution is `python-tds`, the import name `pytds` (installing a package
called `pytds` fails: that PyPI project is an unrelated empty placeholder).
No cafile means python-tds negotiates no encryption, which both targets
allow (RDS with rds.forceSSL off, the dev container with Force Encryption
off); prod traffic stays in the VPC and dev traffic on the compose network.

A failed connection is reported as mssql_up 0 rather than a task failure or
a dead endpoint, so alerting fires from Prometheus. A failure inside one
section degrades only that section: what could be collected still ships,
and mssql_collect_errors counts the sections that could not.
"""

import datetime as dt
import json
import os
import sys
import urllib.request

import pytds

SECRET_NAME = os.environ.get("DB_SECRET_NAME", "")
DATABASE = os.environ.get("DB_NAME", "master")
REGION = os.environ.get("AWS_REGION", "eu-west-1")
TIMEOUT = int(os.environ.get("DB_TIMEOUT_SECONDS", "15"))

# Per-database sizes straight from the catalog: total (the series the Express
# 10 GB alert evaluates) plus the data/log split that says which side grows.
DATABASE_SIZES = """
SELECT DB_NAME(database_id) AS db,
       SUM(size) * 8 * 1024 AS bytes,
       SUM(CASE WHEN type = 0 THEN size ELSE 0 END) * 8 * 1024 AS data_bytes,
       SUM(CASE WHEN type = 1 THEN size ELSE 0 END) * 8 * 1024 AS log_bytes
FROM sys.master_files
GROUP BY database_id
"""

SESSIONS_BY_DATABASE = """
SELECT DB_NAME(database_id) AS db, COUNT(*) AS value
FROM sys.dm_exec_sessions
WHERE is_user_process = 1 AND database_id > 0
GROUP BY database_id
"""

USER_CONNECTIONS = "SELECT COUNT(*) AS value FROM sys.dm_exec_sessions WHERE is_user_process = 1"

BLOCKED_SESSIONS = "SELECT COUNT(*) AS value FROM sys.dm_exec_requests WHERE blocking_session_id <> 0"

BLOCKED_BY_DATABASE = """
SELECT DB_NAME(database_id) AS db, COUNT(*) AS value
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0
GROUP BY database_id
"""

# One pass over the performance counters. The per-database counters carry the
# database name in instance_name — that label is what makes deadlocks,
# transactions and log usage attributable to a single database. The instance
# filter matters: without it 'Deadlocks/sec' returns one row per database AND
# a '_Total' row, and emitting them unlabeled duplicates the series (which
# Pushgateway rejects outright — the bug that silently killed every push).
PERFORMANCE_COUNTERS = """
SELECT RTRIM(counter_name) AS counter_name,
       RTRIM(instance_name) AS instance_name,
       cntr_value
FROM sys.dm_os_performance_counters
WHERE counter_name IN (
    'Deadlocks/sec', 'Transactions/sec', 'Log Growths',
    'Log File(s) Used Size (KB)', 'Log File(s) Size (KB)',
    'Batch Requests/sec', 'Logins/sec', 'Page life expectancy',
    'Buffer cache hit ratio', 'Buffer cache hit ratio base',
    'Lazy writes/sec', 'Total Server Memory (KB)', 'Target Server Memory (KB)')
"""

SKIP_INSTANCES = {"", "_total", "mssqlsystemresource"}

# Per-database counters: emitted with a db label. The KB counters become bytes.
PER_DB_COUNTERS = {
    "Deadlocks/sec": ("mssql_deadlocks_total", 1),
    "Transactions/sec": ("mssql_transactions_total", 1),
    "Log Growths": ("mssql_log_growths_total", 1),
    "Log File(s) Used Size (KB)": ("mssql_log_used_bytes", 1024),
    "Log File(s) Size (KB)": ("mssql_log_size_bytes", 1024),
}

# Server-wide counters: single instance, no label — the names the existing
# alert rules and the Services dashboard already evaluate.
SERVER_COUNTERS = {
    "Batch Requests/sec": "mssql_batch_requests_total",
    "Logins/sec": "mssql_logins_total",
    "Page life expectancy": "mssql_page_life_expectancy_seconds",
    "Lazy writes/sec": "mssql_lazy_writes_total",
}

MEMORY_COUNTERS = {
    "Total Server Memory (KB)": "total",
    "Target Server Memory (KB)": "target",
}

# The database name is read from the server itself and quoted inline: pytds
# paramstyles differ between builds, and there is nothing user-supplied here.
VOLUME_STATS = """
SELECT volume_mount_point AS mount, total_bytes, available_bytes
FROM sys.dm_os_volume_stats(DB_ID(N'%s'), NULL)
"""


def escape_label(value):
    return str(value).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def read_secret():
    import boto3  # lazy: serve mode on dev never needs AWS credentials

    client = boto3.client("secretsmanager", region_name=REGION)
    payload = json.loads(client.get_secret_value(SecretId=SECRET_NAME)["SecretString"])
    # RDS-managed secrets hold only username/password; host/port then come
    # from the task environment (set from the aws_db_instance data source).
    host = os.environ.get("DB_HOST") or payload["host"]
    port = int(os.environ.get("DB_PORT") or payload.get("port", 1433))
    return payload["username"], payload["password"], host, port


def resolve_target():
    if SECRET_NAME:
        return read_secret()
    return (
        os.environ["DB_USER"],
        os.environ["DB_PASSWORD"],
        os.environ["DB_HOST"],
        int(os.environ.get("DB_PORT", "1433")),
    )


def query(cursor, sql):
    cursor.execute(sql)
    columns = [column[0] for column in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def collect():
    """Returns (metrics, errors): the exposition lines and the number of
    sections that failed. The caller adds mssql_up / timestamp / errors."""
    metrics = []
    errors = 0
    user, password, host, port = resolve_target()

    with pytds.connect(dsn=host, user=user, password=password, database=DATABASE, port=port, timeout=TIMEOUT, as_dict=True) as conn:
        with conn.cursor() as cursor:
            # Sizes first: the volume section reuses the database list.
            databases = []
            try:
                databases = query(cursor, DATABASE_SIZES)
                for row in databases:
                    if not row["db"]:
                        continue
                    db = escape_label(row["db"])
                    metrics.append('mssql_database_size_bytes{db="%s"} %d' % (db, int(row["bytes"])))
                    metrics.append('mssql_data_file_size_bytes{db="%s"} %d' % (db, int(row["data_bytes"])))
                    metrics.append('mssql_log_file_size_bytes{db="%s"} %d' % (db, int(row["log_bytes"])))
            except Exception as exc:
                errors += 1
                print(json.dumps({"section": "sizes", "error": str(exc)}), file=sys.stderr)

            for name, sql, label in (
                ("sessions", SESSIONS_BY_DATABASE, "mssql_sessions"),
                ("blocked_by_db", BLOCKED_BY_DATABASE, "mssql_blocked_sessions"),
            ):
                try:
                    for row in query(cursor, sql):
                        if row["db"]:
                            metrics.append('%s{db="%s"} %d' % (label, escape_label(row["db"]), int(row["value"])))
                except Exception as exc:
                    errors += 1
                    print(json.dumps({"section": name, "error": str(exc)}), file=sys.stderr)

            try:
                metrics.append("mssql_user_connections %d" % int(query(cursor, USER_CONNECTIONS)[0]["value"]))
                metrics.append("mssql_blocked_sessions %d" % int(query(cursor, BLOCKED_SESSIONS)[0]["value"]))
            except Exception as exc:
                errors += 1
                print(json.dumps({"section": "connections", "error": str(exc)}), file=sys.stderr)

            try:
                ratio = {}
                for row in query(cursor, PERFORMANCE_COUNTERS):
                    counter = row["counter_name"].strip()
                    instance = row["instance_name"].strip()
                    value = int(row["cntr_value"])

                    if counter == "Buffer cache hit ratio":
                        ratio["value"] = value
                    elif counter == "Buffer cache hit ratio base":
                        ratio["base"] = value
                    elif counter in MEMORY_COUNTERS:
                        metrics.append('mssql_server_memory_bytes{kind="%s"} %d' % (MEMORY_COUNTERS[counter], value * 1024))
                    elif counter in SERVER_COUNTERS:
                        metrics.append("%s %d" % (SERVER_COUNTERS[counter], value))
                    elif counter in PER_DB_COUNTERS and instance.lower() not in SKIP_INSTANCES:
                        name, factor = PER_DB_COUNTERS[counter]
                        metrics.append('%s{db="%s"} %d' % (name, escape_label(instance), value * factor))

                if ratio.get("base"):
                    metrics.append("mssql_buffer_cache_hit_ratio_percent %d" % round(ratio["value"] * 100.0 / ratio["base"]))
            except Exception as exc:
                errors += 1
                print(json.dumps({"section": "counters", "error": str(exc)}), file=sys.stderr)

            # Volume stats are per-database calls; on SQL Server on Linux the
            # DMV can refuse, so each database is its own guarded attempt and a
            # failure leaves the rest of the push intact.
            try:
                seen_mounts = set()
                for row in databases:
                    if not row["db"]:
                        continue
                    try:
                        volumes = query(cursor, VOLUME_STATS % row["db"].replace("'", "''"))
                    except Exception:
                        continue
                    for volume in volumes:
                        mount = str(volume["mount"]).replace("\\", "\\\\")
                        if mount in seen_mounts:
                            continue
                        seen_mounts.add(mount)
                        metrics.append('mssql_volume_total_bytes{mount="%s"} %d' % (mount, int(volume["total_bytes"])))
                        metrics.append('mssql_volume_available_bytes{mount="%s"} %d' % (mount, int(volume["available_bytes"])))
            except Exception as exc:
                errors += 1
                print(json.dumps({"section": "volumes", "error": str(exc)}), file=sys.stderr)

    return metrics, errors


def collect_with_meta():
    stamp = int(dt.datetime.now(dt.timezone.utc).timestamp())
    try:
        metrics, errors = collect()
        up = 1
    except Exception as exc:  # any connection failure means "not reachable"
        print(json.dumps({"error": str(exc), "target": SECRET_NAME or os.environ.get("DB_HOST", "?")}), file=sys.stderr)
        metrics, errors, up = [], 1, 0
    metrics.append("mssql_up %d" % up)
    metrics.append("mssql_collect_errors %d" % errors)
    metrics.append("mssql_scrape_timestamp_seconds %d" % stamp)
    return metrics


def push(metrics, instance):
    body = "\n".join(metrics) + "\n"
    request = urllib.request.Request(
        "%s/metrics/job/mssql/instance/%s" % (os.environ["PUSHGATEWAY_URL"].rstrip("/"), instance),
        data=body.encode(),
        headers={"Content-Type": "text/plain"},
        method="PUT",
    )
    urllib.request.urlopen(request, timeout=10).read()


def serve():
    """Long-lived /metrics endpoint (dev): every Prometheus scrape re-runs the
    DMV queries, so the values are never older than the scrape interval."""
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    port = int(os.environ["SERVE_PORT"])

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path.split("?")[0] == "/metrics":
                body = ("\n".join(collect_with_meta()) + "\n").encode()
                self.send_response(200)
                self.send_header("Content-Type", "text/plain; version=0.0.4")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            elif self.path.split("?")[0] in ("/", "/health"):
                body = b"ok\n"
                self.send_response(200)
                self.send_header("Content-Type", "text/plain")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            else:
                self.send_response(404)
                self.send_header("Content-Length", "0")
                self.end_headers()

        def log_message(self, fmt, *args):  # one JSON line per request, like the rest of the stack
            print(json.dumps({"path": self.path, "status": fmt % args}), file=sys.stderr)

    print(json.dumps({"serve": port}), file=sys.stderr)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()


def main():
    if os.environ.get("SERVE_PORT"):
        serve()
        return 0

    host = "unknown"
    try:
        _, _, host, _ = resolve_target()
    except Exception:
        pass  # the instance label stays "unknown"; mssql_up 0 tells the story
    metrics = collect_with_meta()
    push(metrics, host)
    print(json.dumps({"host": host, "metrics": len(metrics)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
