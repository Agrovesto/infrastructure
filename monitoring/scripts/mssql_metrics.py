#!/usr/bin/env python3
"""Publish prod SQL Server (RDS) metrics to Pushgateway.

Runs as a scheduled Fargate task. Connection details come from the prod
Secrets Manager secret; the queries are SQL Server DMVs, read over TDS with the
pure-Python `pytds` client (no ODBC driver, no CloudWatch, no Performance
Insights). Prometheus scrapes the values from Pushgateway and the database
alert rules evaluate them.

A failed connection is reported as mssql_up 0 rather than a task failure, so
the alert fires from Prometheus and the task stops cleanly.
"""

import datetime as dt
import json
import os
import sys
import urllib.request

import boto3
import pytds

SECRET_NAME = os.environ["DB_SECRET_NAME"]
PUSHGATEWAY = os.environ["PUSHGATEWAY_URL"].rstrip("/")
DATABASE = os.environ.get("DB_NAME", "master")
REGION = os.environ.get("AWS_REGION", "eu-west-1")
TIMEOUT = int(os.environ.get("DB_TIMEOUT_SECONDS", "15"))

SIZE_BY_DATABASE = """
SELECT DB_NAME(database_id) AS db, SUM(size) * 8 * 1024 AS bytes
FROM sys.master_files
GROUP BY database_id
"""

USER_CONNECTIONS = "SELECT COUNT(*) AS value FROM sys.dm_exec_sessions WHERE is_user_process = 1"

BLOCKED_SESSIONS = "SELECT COUNT(*) AS value FROM sys.dm_exec_requests WHERE blocking_session_id <> 0"

PERFORMANCE_COUNTERS = """
SELECT RTRIM(counter_name) AS counter_name, cntr_value AS value
FROM sys.dm_os_performance_counters
WHERE counter_name IN ('Deadlocks/sec', 'Batch Requests/sec', 'Page life expectancy', 'Logins/sec')
"""

# The database name is read from the server itself and quoted inline: pytds
# paramstyles differ between builds, and there is nothing user-supplied here.
VOLUME_STATS = """
SELECT volume_mount_point AS mount, total_bytes, available_bytes
FROM sys.dm_os_volume_stats(DB_ID(N'%s'), NULL)
"""

COUNTER_METRICS = {
    "Deadlocks/sec": "mssql_deadlocks_total",
    "Batch Requests/sec": "mssql_batch_requests_total",
    "Logins/sec": "mssql_logins_total",
    "Page life expectancy": "mssql_page_life_expectancy_seconds",
}


def read_secret():
    client = boto3.client("secretsmanager", region_name=REGION)
    payload = json.loads(client.get_secret_value(SecretId=SECRET_NAME)["SecretString"])
    # RDS-managed secrets hold only username/password; host/port then come
    # from the task environment (set from the aws_db_instance data source).
    host = os.environ.get("DB_HOST") or payload["host"]
    port = int(os.environ.get("DB_PORT") or payload.get("port", 1433))
    return payload["username"], payload["password"], host, port


def push(metrics, instance):
    body = "\n".join(metrics) + "\n"
    request = urllib.request.Request(
        f"{PUSHGATEWAY}/metrics/job/mssql/instance/{instance}",
        data=body.encode(),
        headers={"Content-Type": "text/plain"},
        method="PUT",
    )
    urllib.request.urlopen(request, timeout=10).read()


def query(cursor, sql):
    cursor.execute(sql)
    columns = [column[0] for column in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def collect():
    metrics = []
    user, password, host, port = read_secret()
    with pytds.connect(host, user, password, database=DATABASE, port=port, timeout=TIMEOUT, as_dict=True) as conn:
        with conn.cursor() as cursor:
            databases = query(cursor, SIZE_BY_DATABASE)
            for row in databases:
                if row["db"]:
                    metrics.append('mssql_database_size_bytes{db="%s"} %d' % (row["db"], int(row["bytes"])))

            metrics.append("mssql_user_connections %d" % int(query(cursor, USER_CONNECTIONS)[0]["value"]))
            metrics.append("mssql_blocked_sessions %d" % int(query(cursor, BLOCKED_SESSIONS)[0]["value"]))

            for row in query(cursor, PERFORMANCE_COUNTERS):
                name = COUNTER_METRICS.get(row["counter_name"].strip())
                if name:
                    metrics.append("%s %d" % (name, int(row["value"])))

            for row in databases:
                if not row["db"]:
                    continue
                volumes = query(cursor, VOLUME_STATS % row["db"].replace("'", "''"))
                for volume in volumes:
                    mount = str(volume["mount"]).replace("\\", "\\\\")
                    metrics.append('mssql_volume_total_bytes{mount="%s"} %d' % (mount, int(volume["total_bytes"])))
                    metrics.append('mssql_volume_available_bytes{mount="%s"} %d' % (mount, int(volume["available_bytes"])))

    return metrics


def main():
    stamp = int(dt.datetime.now(dt.timezone.utc).timestamp())
    host = "unknown"

    try:
        _, _, host, _ = read_secret()
        metrics = collect()
        up = 1
    except Exception as exc:  # any failure means "not reachable"
        print(json.dumps({"error": str(exc), "secret": SECRET_NAME}), file=sys.stderr)
        metrics = []
        up = 0

    metrics.append("mssql_up %d" % up)
    metrics.append("mssql_scrape_timestamp_seconds %d" % stamp)
    push(metrics, host)
    print(json.dumps({"host": host, "up": up, "metrics": len(metrics)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
