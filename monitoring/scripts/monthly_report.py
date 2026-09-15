#!/usr/bin/env python3
"""Send the monthly cost, usage and analysis report as a PDF.

Runs as a scheduled Fargate task on the first of the month. The previous month
(and the one before it, for the comparison) is read straight from the Cost and
Usage Report with DuckDB, rendered with fpdf2 and mailed through SES.
"""

import datetime as dt
import os
import sys
import urllib.request
from email.message import EmailMessage

import boto3
import duckdb
from fpdf import FPDF

REGION = os.environ.get("CUR_REGION", "us-east-1")
BUCKET = os.environ["CUR_BUCKET"]
PREFIX = os.environ.get("CUR_PREFIX", "cur")
REPORT = os.environ["CUR_REPORT_NAME"]
BUDGET = float(os.environ.get("BUDGET_USD", "0") or 0)
RECIPIENTS = [a.strip() for a in os.environ.get("REPORT_RECIPIENTS", "").split(",") if a.strip()]
SENDER = os.environ["REPORT_SENDER"]
SES_REGION = os.environ.get("SES_REGION", "eu-west-1")
PUSHGATEWAY = os.environ.get("PUSHGATEWAY_URL", "").rstrip("/")

TODAY = dt.datetime.now(dt.timezone.utc).date()
THIS_MONTH = TODAY.replace(day=1)
LAST_END = THIS_MONTH - dt.timedelta(days=1)
LAST = LAST_END.replace(day=1)
PREV_END = LAST - dt.timedelta(days=1)
PREV = PREV_END.replace(day=1)


def month_files(s3, month):
    """Parquet objects delivered for the report period that starts at `month`."""
    prefix = f"{PREFIX}/{REPORT}/{REPORT}/"
    folder = f"{month:%Y%m%d}-"
    keys = []
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=BUCKET, Prefix=prefix, PaginationConfig={"PageSize": 1000}):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if key.endswith(".parquet") and key.startswith(prefix + folder):
                keys.append(f"s3://{BUCKET}/{key}")
    return keys


def connect():
    credentials = boto3.session.Session().get_credentials().get_frozen_credentials()
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
    return con


def collect(con, files):
    """Totals, per-service and per-account cost, and the usage lines behind them."""
    total = con.execute(
        "SELECT coalesce(sum(line_item_unblended_cost), 0) FROM read_parquet($files)",
        {"files": files},
    ).fetchone()[0]
    by_service = con.execute(
        """
        SELECT line_item_product_code, sum(line_item_unblended_cost)
        FROM read_parquet($files)
        WHERE line_item_line_item_type NOT IN ('Tax', 'Credit', 'Refund')
        GROUP BY 1
        HAVING sum(line_item_unblended_cost) > 0.005
        ORDER BY 2 DESC
        """,
        {"files": files},
    ).fetchall()
    by_account = con.execute(
        """
        SELECT line_item_usage_account_id, sum(line_item_unblended_cost)
        FROM read_parquet($files)
        WHERE line_item_line_item_type NOT IN ('Tax', 'Credit', 'Refund')
        GROUP BY 1
        HAVING sum(line_item_unblended_cost) > 0.005
        ORDER BY 2 DESC
        """,
        {"files": files},
    ).fetchall()
    usage = con.execute(
        """
        SELECT line_item_usage_type, sum(line_item_usage_amount), sum(line_item_unblended_cost)
        FROM read_parquet($files)
        WHERE line_item_line_item_type = 'Usage' AND line_item_usage_amount > 0
        GROUP BY 1
        ORDER BY 3 DESC
        LIMIT 10
        """,
        {"files": files},
    ).fetchall()
    return {
        "total": float(total),
        "by_service": [(name, float(cost)) for name, cost in by_service],
        "by_account": [(account, float(cost)) for account, cost in by_account],
        "usage": [(name, float(amount), float(cost)) for name, amount, cost in usage],
    }


def money(value):
    return f"${value:,.2f}"


def bar(pdf, share, width, height=3.4):
    x, y = pdf.get_x(), pdf.get_y()
    pdf.set_fill_color(226, 232, 238)
    pdf.rect(x, y + 0.6, width, height, style="F")
    pdf.set_fill_color(31, 119, 180)
    pdf.rect(x, y + 0.6, max(share, 0.01) * width, height, style="F")
    pdf.set_xy(x, y)


def analysis(current, previous):
    bullets = []
    delta = current["total"] - previous["total"]
    change = (delta / previous["total"] * 100) if previous["total"] else 0
    bullets.append(
        f"Spend moved {money(abs(delta))} ({change:+.1f} %) against "
        f"{PREV:%B %Y} ({money(previous['total'])})."
    )
    if BUDGET:
        used = current["total"] / BUDGET * 100
        verdict = "over" if current["total"] > BUDGET else "within"
        bullets.append(
            f"The month closed {verdict} the {money(BUDGET)} budget at {used:.0f} % "
            f"({money(current['total'])})."
        )
    now = dict(current["by_service"])
    before = dict(previous["by_service"])
    movers = sorted(
        ((name, now.get(name, 0) - before.get(name, 0)) for name in set(now) | set(before)),
        key=lambda item: item[1],
    )
    for name, moved in movers[-2:][::-1]:
        if moved > 1:
            bullets.append(f"{name} added {money(moved)} month over month.")
    for name, moved in movers[:2]:
        if moved < -1:
            bullets.append(f"{name} fell {money(abs(moved))} month over month.")
    new_items = sorted(set(now) - set(before))
    if new_items:
        bullets.append("New line items: " + ", ".join(new_items) + ".")
    if len(current["by_account"]) > 1 and current["total"]:
        top = current["by_account"][0]
        bullets.append(
            f"Account {top[0]} carries {top[1] / current['total'] * 100:.0f} % of the bill "
            f"across {len(current['by_account'])} accounts."
        )
    return bullets


def render(current, previous):
    pdf = FPDF(orientation="P", unit="mm", format="A4")
    pdf.set_auto_page_break(auto=True, margin=18)
    pdf.add_page()

    pdf.set_font("Helvetica", "B", 18)
    pdf.cell(0, 10, "Agrovesto - monthly cost report", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 12)
    pdf.set_text_color(90)
    pdf.cell(0, 6, f"{LAST:%B %Y} (closed {LAST_END:%Y-%m-%d})", new_x="LMARGIN", new_y="NEXT")
    pdf.set_text_color(0)
    pdf.ln(4)

    pdf.set_font("Helvetica", "B", 26)
    pdf.cell(0, 12, money(current["total"]), new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 11)
    pdf.cell(
        0,
        6,
        f"{current['total'] - previous['total']:+,.2f} USD vs {PREV:%B %Y}  |  "
        f"budget {money(BUDGET) if BUDGET else 'n/a'}  |  "
        f"{len(current['by_service'])} services  |  {len(current['by_account'])} accounts",
        new_x="LMARGIN",
        new_y="NEXT",
    )
    pdf.ln(4)

    pdf.set_font("Helvetica", "B", 13)
    pdf.cell(0, 8, "Cost by service", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    share_total = current["total"] or 1
    for name, cost in current["by_service"][:12]:
        pdf.cell(62, 6, name[:38])
        pdf.cell(24, 6, money(cost), align="R")
        pdf.cell(14, 6, f"{cost / share_total * 100:.1f} %", align="R")
        pdf.cell(5, 6, "")
        bar(pdf, cost / share_total, 58)
        pdf.ln(6)
    pdf.ln(3)

    pdf.set_font("Helvetica", "B", 13)
    pdf.cell(0, 8, "Usage highlights", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    for name, amount, cost in current["usage"][:8]:
        pdf.cell(98, 6, name[:60])
        pdf.cell(28, 6, f"{amount:,.2f}", align="R")
        pdf.cell(24, 6, money(cost), align="R")
        pdf.ln(6)
    pdf.ln(3)

    pdf.set_font("Helvetica", "B", 13)
    pdf.cell(0, 8, "Analysis", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    for bullet in analysis(current, previous):
        pdf.multi_cell(0, 6, f"- {bullet}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(4)

    pdf.set_font("Helvetica", "I", 8)
    pdf.set_text_color(120)
    pdf.multi_cell(
        0,
        4,
        "Source: Cost and Usage Report (Parquet) aggregated with DuckDB inside the "
        "monitoring stack. Amounts are unblended cost, excluding tax, credits and refunds.",
        new_x="LMARGIN",
        new_y="NEXT",
    )
    return bytes(pdf.output())


def send(pdf_bytes, current):
    message = EmailMessage()
    message["Subject"] = f"Agrovesto cost report - {LAST:%B %Y} ({money(current['total'])})"
    message["From"] = SENDER
    message["To"] = ", ".join(RECIPIENTS)
    message.set_content(
        f"Attached: the {LAST:%B %Y} cost, usage and analysis report "
        f"(total {money(current['total'])}). Source: Cost and Usage Report."
    )
    message.add_attachment(
        pdf_bytes,
        maintype="application",
        subtype="pdf",
        filename=f"agrovesto-costs-{LAST:%Y-%m}.pdf",
    )
    boto3.client("ses", region_name=SES_REGION).send_raw_email(
        Source=SENDER,
        Destinations=RECIPIENTS,
        RawMessage={"Data": message.as_bytes()},
    )


def push(current, previous):
    if not PUSHGATEWAY:
        return
    body = "\n".join(
        [
            f"cost_last_month_usd {current['total']:.4f}",
            f"cost_previous_month_usd {previous['total']:.4f}",
            f"cost_last_month_budget_ratio {(current['total'] / BUDGET if BUDGET else 0):.4f}",
            f"cost_report_timestamp_seconds {int(dt.datetime.now(dt.timezone.utc).timestamp())}",
        ]
    )
    request = urllib.request.Request(
        f"{PUSHGATEWAY}/metrics/job/monthly_report",
        data=(body + "\n").encode(),
        headers={"Content-Type": "text/plain"},
        method="PUT",
    )
    urllib.request.urlopen(request, timeout=10).read()


def main():
    if not RECIPIENTS:
        print("no recipients configured; nothing to send")
        return 0
    s3 = boto3.client("s3", region_name=REGION)
    current_files = month_files(s3, LAST)
    previous_files = month_files(s3, PREV)
    if not current_files:
        print(f"no CUR objects for {LAST:%Y-%m}; nothing to report")
        return 1
    con = connect()
    current = collect(con, current_files)
    previous = collect(con, previous_files) if previous_files else {
        "total": 0.0,
        "by_service": [],
        "by_account": [],
        "usage": [],
    }
    pdf_bytes = render(current, previous)
    send(pdf_bytes, current)
    push(current, previous)
    print(
        f"sent {LAST:%Y-%m}: total {current['total']:.2f}, previous {previous['total']:.2f}, "
        f"{len(current['by_service'])} services, {len(pdf_bytes)} bytes"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
