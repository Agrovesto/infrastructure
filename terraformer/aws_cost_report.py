#!/usr/bin/env python3

import csv
import json
import subprocess
from datetime import date
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
OUTPUT = BASE_DIR / "aws-cost-report.csv"

PROFILES = [
    "agrovesto-dev",
    "agrovesto-prod",
]


def run_aws(profile, command):
    result = subprocess.run(
        [
            "aws",
            *command,
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
            f"AWS CLI failed for profile {profile}:\n"
            f"{result.stderr.strip()}"
        )

    return json.loads(result.stdout)


def get_account_id(profile):
    data = run_aws(
        profile,
        ["sts", "get-caller-identity"],
    )

    return data["Account"]


def get_cost_by_service(
    profile,
    start_date,
    end_date,
):
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
            "UnblendedCost",
            "--group-by",
            "Type=DIMENSION,Key=SERVICE",
        ],
    )


def get_forecast(profile, start_date, end_date):
    return run_aws(
        profile,
        [
            "ce",
            "get-cost-forecast",
            "--time-period",
            f"Start={start_date},End={end_date}",
            "--metric",
            "UNBLENDED_COST",
            "--granularity",
            "MONTHLY",
        ],
    )


def extract_service_costs(data):
    results = []

    for period in data.get("ResultsByTime", []):
        period_start = period["TimePeriod"]["Start"]

        for group in period.get("Groups", []):
            service = group["Keys"][0]

            amount = float(
                group["Metrics"]["UnblendedCost"]["Amount"]
            )

            if amount == 0:
                continue

            results.append(
                {
                    "period": period_start,
                    "service": service,
                    "cost_usd": amount,
                }
            )

    return results


def main():
    today = date.today()

    # Current calendar month
    current_month_start = today.replace(day=1)

    # Previous month
    if current_month_start.month == 1:
        previous_month_start = date(
            current_month_start.year - 1,
            12,
            1,
        )
    else:
        previous_month_start = date(
            current_month_start.year,
            current_month_start.month - 1,
            1,
        )

    # End of previous month = start of current month
    previous_month_end = current_month_start

    # End of current month
    if current_month_start.month == 12:
        current_month_end = date(
            current_month_start.year + 1,
            1,
            1,
        )
    else:
        current_month_end = date(
            current_month_start.year,
            current_month_start.month + 1,
            1,
        )

    rows = []

    print()
    print("=" * 80)
    print("AWS COST REPORT")
    print("=" * 80)
    print()

    for profile in PROFILES:
        print(f"Processing: {profile}")

        account_id = get_account_id(profile)

        print(f"Account ID : {account_id}")

        # ----------------------------------------------------
        # Previous complete month
        # ----------------------------------------------------

        previous = get_cost_by_service(
            profile,
            previous_month_start.isoformat(),
            previous_month_end.isoformat(),
        )

        previous_costs = extract_service_costs(previous)

        for item in previous_costs:
            rows.append(
                {
                    "account": profile,
                    "account_id": account_id,
                    "period": item["period"],
                    "period_type": "previous_month_actual",
                    "service": item["service"],
                    "cost_usd": f'{item["cost_usd"]:.2f}',
                }
            )

        # ----------------------------------------------------
        # Current month MTD
        # ----------------------------------------------------

        current = get_cost_by_service(
            profile,
            current_month_start.isoformat(),
            today.isoformat(),
        )

        current_costs = extract_service_costs(current)

        for item in current_costs:
            rows.append(
                {
                    "account": profile,
                    "account_id": account_id,
                    "period": item["period"],
                    "period_type": "current_month_mtd",
                    "service": item["service"],
                    "cost_usd": f'{item["cost_usd"]:.2f}',
                }
            )

        # ----------------------------------------------------
        # Current month forecast
        # ----------------------------------------------------

        try:
            forecast = get_forecast(
                profile,
                current_month_start.isoformat(),
                current_month_end.isoformat(),
            )

            forecast_amount = float(
                forecast["Total"]["Amount"]
            )

            rows.append(
                {
                    "account": profile,
                    "account_id": account_id,
                    "period": current_month_start.isoformat(),
                    "period_type": "current_month_forecast_total",
                    "service": "TOTAL",
                    "cost_usd": f"{forecast_amount:.2f}",
                }
            )

            print(
                f"Forecast   : ${forecast_amount:,.2f}"
            )

        except Exception as exc:
            print(
                f"Forecast unavailable for {profile}: {exc}"
            )

        print()

    # --------------------------------------------------------
    # CSV
    # --------------------------------------------------------

    fields = [
        "account",
        "account_id",
        "period",
        "period_type",
        "service",
        "cost_usd",
    ]

    with OUTPUT.open(
        "w",
        newline="",
        encoding="utf-8",
    ) as f:
        writer = csv.DictWriter(
            f,
            fieldnames=fields,
        )

        writer.writeheader()
        writer.writerows(rows)

    # --------------------------------------------------------
    # Summary
    # --------------------------------------------------------

    print("=" * 80)
    print(f"CSV written to: {OUTPUT}")
    print(f"Rows          : {len(rows):,}")
    print("=" * 80)


if __name__ == "__main__":
    main()
