#!/usr/bin/env python3

"""
AWS Cost Explorer report v2.

Produces one CSV containing:
- Previous complete month actual usage by service
- Previous complete month credits/tax/net
- Current month-to-date usage by service
- Current month-to-date credits/tax/net
- Simple month-end run-rate estimate (usage/net)

Profiles are intentionally hard-coded for the two Agrovesto accounts.
"""

import csv
import json
import subprocess
from collections import defaultdict
from datetime import date, timedelta
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
OUTPUT = BASE_DIR / "aws-cost-report-v2.csv"

PROFILES = [
    "agrovesto-dev",
    "agrovesto-prod",
]

METRIC = "UnblendedCost"


def run_aws(profile, args):
    result = subprocess.run(
        [
            "aws",
            *args,
            "--profile",
            profile,
            "--output",
            "json",
            "--no-cli-pager",
        ],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"AWS CLI failed for {profile}:\n{result.stderr.strip()}"
        )

    return json.loads(result.stdout)


def get_account_id(profile):
    return run_aws(
        profile,
        ["sts", "get-caller-identity"],
    )["Account"]


def get_cost_by_service(profile, start_date, end_date):
    """Return service costs for Usage records only."""
    return run_aws(
        profile,
        [
            "ce",
            "get-cost-and-usage",
            "--time-period",
            f"Start={start_date},End={end_date}",
            "--granularity",
            "MONTHLY",
            "--metrics",
            METRIC,
            "--filter",
            json.dumps(
                {
                    "Dimensions": {
                        "Key": "RECORD_TYPE",
                        "Values": ["Usage"],
                    }
                }
            ),
            "--group-by",
            "Type=DIMENSION,Key=SERVICE",
        ],
    )


def get_record_type_totals(profile, start_date, end_date):
    return run_aws(
        profile,
        [
            "ce",
            "get-cost-and-usage",
            "--time-period",
            f"Start={start_date},End={end_date}",
            "--granularity",
            "MONTHLY",
            "--metrics",
            METRIC,
            "--group-by",
            "Type=DIMENSION,Key=RECORD_TYPE",
        ],
    )


def get_service_costs(data):
    result = defaultdict(float)

    for period in data.get("ResultsByTime", []):
        for group in period.get("Groups", []):
            service = group["Keys"][0]
            amount = float(group["Metrics"][METRIC]["Amount"])
            result[service] += amount

    return dict(result)


def get_record_types(data):
    result = defaultdict(float)

    for period in data.get("ResultsByTime", []):
        for group in period.get("Groups", []):
            record_type = group["Keys"][0]
            amount = float(group["Metrics"][METRIC]["Amount"])
            result[record_type] += amount

    return dict(result)


def next_month_start(d):
    if d.month == 12:
        return date(d.year + 1, 1, 1)
    return date(d.year, d.month + 1, 1)


def days_in_month(d):
    return (next_month_start(d) - d).days


def run_rate(value, elapsed_days, total_days):
    if elapsed_days <= 0:
        return 0.0
    return (value / elapsed_days) * total_days


def append_row(
    rows,
    *,
    account,
    account_id,
    period,
    period_type,
    service,
    usage=0.0,
    credit=0.0,
    tax=0.0,
    net=0.0,
    estimated_month_end=0.0,
):
    rows.append(
        {
            "account": account,
            "account_id": account_id,
            "period": period,
            "period_type": period_type,
            "service": service,
            "usage_usd": f"{usage:.10f}",
            "credit_usd": f"{credit:.10f}",
            "tax_usd": f"{tax:.10f}",
            "net_usd": f"{net:.10f}",
            "estimated_month_end_usd": f"{estimated_month_end:.10f}",
        }
    )


def main():
    today = date.today()
    current_month_start = today.replace(day=1)
    current_month_end = next_month_start(current_month_start)

    if current_month_start.month == 1:
        previous_month_start = date(current_month_start.year - 1, 12, 1)
    else:
        previous_month_start = date(
            current_month_start.year,
            current_month_start.month - 1,
            1,
        )

    previous_month_end = current_month_start

    # Cost Explorer End is exclusive. Include today by querying tomorrow,
    # but never cross into the next month.
    mtd_end = min(today + timedelta(days=1), current_month_end)

    rows = []

    print("=" * 80)
    print("AWS COST REPORT V2")
    print("=" * 80)
    print()

    for profile in PROFILES:
        print(f"Processing: {profile}")

        account_id = get_account_id(profile)
        print(f"Account ID : {account_id}")

        # ----------------------------------------------------
        # Previous complete month
        # ----------------------------------------------------
        previous_services = get_service_costs(
            get_cost_by_service(
                profile,
                previous_month_start.isoformat(),
                previous_month_end.isoformat(),
            )
        )

        previous_records = get_record_types(
            get_record_type_totals(
                profile,
                previous_month_start.isoformat(),
                previous_month_end.isoformat(),
            )
        )

        previous_usage = previous_records.get("Usage", 0.0)
        previous_credit = previous_records.get("Credit", 0.0)
        previous_tax = previous_records.get("Tax", 0.0)
        previous_net = previous_usage + previous_credit + previous_tax

        print(f"Previous usage : ${previous_usage:,.6f}")
        print(f"Previous credit: ${previous_credit:,.6f}")
        print(f"Previous tax   : ${previous_tax:,.6f}")
        print(f"Previous net   : ${previous_net:,.6f}")

        for service, usage in sorted(
            previous_services.items(),
            key=lambda item: (-item[1], item[0]),
        ):
            if usage == 0:
                continue

            append_row(
                rows,
                account=profile,
                account_id=account_id,
                period=previous_month_start.isoformat(),
                period_type="previous_month_actual",
                service=service,
                usage=usage,
                net=usage,
            )

        append_row(
            rows,
            account=profile,
            account_id=account_id,
            period=previous_month_start.isoformat(),
            period_type="previous_month_total",
            service="TOTAL",
            usage=previous_usage,
            credit=previous_credit,
            tax=previous_tax,
            net=previous_net,
        )

        # ----------------------------------------------------
        # Current month-to-date
        # ----------------------------------------------------
        current_services = get_service_costs(
            get_cost_by_service(
                profile,
                current_month_start.isoformat(),
                mtd_end.isoformat(),
            )
        )

        current_records = get_record_types(
            get_record_type_totals(
                profile,
                current_month_start.isoformat(),
                mtd_end.isoformat(),
            )
        )

        current_usage = current_records.get("Usage", 0.0)
        current_credit = current_records.get("Credit", 0.0)
        current_tax = current_records.get("Tax", 0.0)
        current_net = current_usage + current_credit + current_tax

        elapsed_days = max(1, (mtd_end - current_month_start).days)
        total_days = days_in_month(current_month_start)

        estimated_month_end_usage = run_rate(
            current_usage,
            elapsed_days,
            total_days,
        )

        estimated_month_end_credit = run_rate(
            current_credit,
            elapsed_days,
            total_days,
        )

        estimated_month_end_tax = run_rate(
            current_tax,
            elapsed_days,
            total_days,
        )

        estimated_month_end_net = (
            estimated_month_end_usage
            + estimated_month_end_credit
            + estimated_month_end_tax
        )

        print(f"Current usage  : ${current_usage:,.6f}")
        print(f"Current credit : ${current_credit:,.6f}")
        print(f"Current tax    : ${current_tax:,.6f}")
        print(f"Current net    : ${current_net:,.6f}")
        print(
            "Month-end usage estimate: "
            f"${estimated_month_end_usage:,.6f}"
        )
        print(
            "Month-end net estimate  : "
            f"${estimated_month_end_net:,.6f}"
        )

        for service, usage in sorted(
            current_services.items(),
            key=lambda item: (-item[1], item[0]),
        ):
            if usage == 0:
                continue

            estimated_service = run_rate(
                usage,
                elapsed_days,
                total_days,
            )

            append_row(
                rows,
                account=profile,
                account_id=account_id,
                period=current_month_start.isoformat(),
                period_type="current_month_mtd",
                service=service,
                usage=usage,
                net=usage,
                estimated_month_end=estimated_service,
            )

        append_row(
            rows,
            account=profile,
            account_id=account_id,
            period=current_month_start.isoformat(),
            period_type="current_month_total",
            service="TOTAL",
            usage=current_usage,
            credit=current_credit,
            tax=current_tax,
            net=current_net,
            estimated_month_end=estimated_month_end_net,
        )

        print()

    fields = [
        "account",
        "account_id",
        "period",
        "period_type",
        "service",
        "usage_usd",
        "credit_usd",
        "tax_usd",
        "net_usd",
        "estimated_month_end_usd",
    ]

    rows.sort(
        key=lambda row: (
            row["account"],
            row["period"],
            row["period_type"],
            row["service"],
        )
    )

    with OUTPUT.open(
        "w",
        newline="",
        encoding="utf-8",
    ) as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    print("=" * 80)
    print(f"CSV written to: {OUTPUT}")
    print(f"Rows          : {len(rows):,}")
    print("=" * 80)


if __name__ == "__main__":
    main()
