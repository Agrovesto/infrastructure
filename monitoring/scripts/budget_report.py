#!/usr/bin/env python3
"""Aggregate the Cost and Usage Report and publish budget metrics to Pushgateway.

Runs as a daily Fargate task. Reads the Parquet report straight from S3 with
DuckDB, then pushes gauge values that Prometheus scrapes from Pushgateway and
the cost alert rules evaluate.
"""

import datetime as dt
import json
import os
import sys
import urllib.request

import boto3
import duckdb

REGION = os.environ.get("CUR_REGION", "us-east-1")
BUCKET = os.environ["CUR_BUCKET"]
PREFIX = os.environ.get("CUR_PREFIX", "cur")
REPORT = os.environ["CUR_REPORT_NAME"]
BUDGET = float(os.environ.get("BUDGET_USD", "0") or 0)
PUSHGATEWAY = os.environ["PUSHGATEWAY_URL"].rstrip("/")

TODAY = dt.datetime.now(dt.timezone.utc).date()
PERIOD_START = TODAY.replace(day=1)
# The delivery folder is named <period-start>-<period-end>.
FOLDER = f"{PREFIX}/{REPORT}/{PERIOD_START:%Y%m%d}-"


def month_to_date_files(s3):
    prefix = f"{PREFIX}/{REPORT}/{REPORT}/"
    paginator = s3.get_paginator("list_objects_v2")
    keys = []
    for page in paginator.paginate(Bucket=BUCKET, Prefix=prefix, PaginationConfig={"PageSize": 1000}):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if not key.endswith(".parquet"):
                continue
            relative = key[len(prefix):]
            if relative.startswith(FOLDER):
                keys.append(f"s3://{BUCKET}/{key}")
    return keys


def push(metrics):
    body = "\n".join(metrics) + "\n"
    request = urllib.request.Request(
        f"{PUSHGATEWAY}/metrics/job/budget",
        data=body.encode(),
        headers={"Content-Type": "text/plain"},
        method="PUT",
    )
    urllib.request.urlopen(request, timeout=10).read()


def main():
    s3 = boto3.client("s3", region_name=REGION)
    files = month_to_date_files(s3)
    if not files:
        print(f"no CUR objects under {FOLDER} yet; nothing to publish")
        return 0

    session = boto3.session.Session()
    credentials = session.get_credentials().get_frozen_credentials()
    con = duckdb.connect()
    con.execute(
        f"""
        CREATE SECRET cur (TYPE S3,
            KEY_ID '{credentials.access_key}',
            SECRET '{credentials.secret_key}',
            SESSION_TOKEN '{credentials.token}',
            REGION '{REGION}')
        """
    )

    total = con.execute("SELECT coalesce(sum(line_item_unblended_cost), 0) FROM read_parquet($files)", {"files": files}).fetchone()[0]
    by_service = con.execute(
        """
        SELECT line_item_product_code, sum(line_item_unblended_cost)
        FROM read_parquet($files)
        GROUP BY 1
        HAVING sum(line_item_unblended_cost) > 0.01
        ORDER BY 2 DESC
        LIMIT 25
        """,
        {"files": files},
    ).fetchall()

    days_elapsed = (TODAY - PERIOD_START).days + 1
    days_in_month = (PERIOD_START.replace(day=28) + dt.timedelta(days=4)).replace(day=1) - dt.timedelta(days=1)
    projected = float(total) / days_elapsed * days_in_month.day

    metrics = [
        f'cost_month_to_date_usd {float(total):.4f}',
        f'cost_projected_month_usd {projected:.4f}',
        f'budget_month_usd {BUDGET:.2f}',
        f'budget_utilization_ratio {(projected / BUDGET if BUDGET else 0):.4f}',
        f'cost_report_timestamp_seconds {int(dt.datetime.now(dt.timezone.utc).timestamp())}',
    ]
    metrics += [
        'cost_by_service_month_to_date_usd{service="%s"} %.4f' % (service, float(cost))
        for service, cost in by_service
    ]

    push(metrics)
    print(json.dumps({"month_to_date_usd": float(total), "projected_usd": projected, "services": len(by_service)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
