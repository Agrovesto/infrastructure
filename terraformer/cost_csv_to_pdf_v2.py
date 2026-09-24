#!/usr/bin/env python3

"""
Convert aws-cost-report-v2.csv into aws-cost-report-v2.pdf.
"""

import csv
from collections import defaultdict
from datetime import datetime
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
    PageBreak,
)

BASE_DIR = Path(__file__).resolve().parent
INPUT_CSV = BASE_DIR / "aws-cost-report-v2.csv"
OUTPUT_PDF = BASE_DIR / "aws-cost-report-v2.pdf"

if not INPUT_CSV.exists():
    raise SystemExit(
        f"ERROR: {INPUT_CSV} not found.\n"
        "Run aws_cost_report_v2.py first."
    )

with INPUT_CSV.open("r", newline="", encoding="utf-8") as f:
    rows = list(csv.DictReader(f))

if not rows:
    raise SystemExit("ERROR: aws-cost-report-v2.csv is empty.")


def num(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def money(value):
    value = num(value)
    if value != 0 and abs(value) < 0.005:
        return f"${value:.8f}"
    return f"${value:,.2f}"


def text(value):
    value = str(value or "-")
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


styles = getSampleStyleSheet()

title_style = ParagraphStyle(
    "CostTitle",
    parent=styles["Title"],
    fontName="Helvetica-Bold",
    fontSize=20,
    leading=24,
    alignment=TA_LEFT,
    textColor=colors.HexColor("#111827"),
)

subtitle_style = ParagraphStyle(
    "CostSubtitle",
    parent=styles["Normal"],
    fontSize=8,
    leading=11,
    textColor=colors.HexColor("#4B5563"),
)

section_style = ParagraphStyle(
    "CostSection",
    parent=styles["Heading2"],
    fontName="Helvetica-Bold",
    fontSize=12,
    leading=15,
    textColor=colors.HexColor("#111827"),
    spaceBefore=4 * mm,
    spaceAfter=3 * mm,
)

header_style = ParagraphStyle(
    "CostHeader",
    parent=styles["Normal"],
    fontName="Helvetica-Bold",
    fontSize=6.2,
    leading=7.5,
    textColor=colors.white,
)

cell_style = ParagraphStyle(
    "CostCell",
    parent=styles["Normal"],
    fontSize=6.2,
    leading=7.5,
)

metric_style = ParagraphStyle(
    "CostMetric",
    parent=styles["Normal"],
    fontName="Helvetica-Bold",
    fontSize=15,
    leading=17,
    alignment=TA_CENTER,
)

label_style = ParagraphStyle(
    "CostLabel",
    parent=styles["Normal"],
    fontSize=7,
    leading=9,
    alignment=TA_CENTER,
    textColor=colors.HexColor("#4B5563"),
)


def P(value, style=cell_style):
    return Paragraph(text(value), style)


accounts = sorted({r.get("account", "") for r in rows if r.get("account")})

previous_totals = {}
current_totals = {}
service_previous = defaultdict(float)
service_current = defaultdict(float)
service_estimate = defaultdict(float)
account_service_previous = defaultdict(float)
account_service_current = defaultdict(float)
account_service_estimate = defaultdict(float)

for row in rows:
    account = row.get("account", "")
    service = row.get("service", "")
    period_type = row.get("period_type", "")

    if service == "TOTAL" and period_type == "previous_month_total":
        previous_totals[account] = {
            "usage": num(row.get("usage_usd")),
            "credit": num(row.get("credit_usd")),
            "tax": num(row.get("tax_usd")),
            "net": num(row.get("net_usd")),
        }

    elif service == "TOTAL" and period_type == "current_month_total":
        current_totals[account] = {
            "usage": num(row.get("usage_usd")),
            "credit": num(row.get("credit_usd")),
            "tax": num(row.get("tax_usd")),
            "net": num(row.get("net_usd")),
            "estimate": num(row.get("estimated_month_end_usd")),
        }

    elif period_type == "previous_month_actual":
        cost = num(row.get("usage_usd"))
        service_previous[service] += cost
        account_service_previous[(account, service)] += cost

    elif period_type == "current_month_mtd":
        cost = num(row.get("usage_usd"))
        estimate = num(row.get("estimated_month_end_usd"))
        service_current[service] += cost
        service_estimate[service] += estimate
        account_service_current[(account, service)] += cost
        account_service_estimate[(account, service)] += estimate

previous_usage_total = sum(v["usage"] for v in previous_totals.values())
previous_credit_total = sum(v["credit"] for v in previous_totals.values())
previous_tax_total = sum(v["tax"] for v in previous_totals.values())
previous_net_total = sum(v["net"] for v in previous_totals.values())

current_usage_total = sum(v["usage"] for v in current_totals.values())
current_credit_total = sum(v["credit"] for v in current_totals.values())
current_tax_total = sum(v["tax"] for v in current_totals.values())
current_net_total = sum(v["net"] for v in current_totals.values())
estimate_total = sum(v["estimate"] for v in current_totals.values())


doc = SimpleDocTemplate(
    str(OUTPUT_PDF),
    pagesize=landscape(A4),
    rightMargin=9 * mm,
    leftMargin=9 * mm,
    topMargin=9 * mm,
    bottomMargin=15 * mm,
    title="AWS Monthly Cost Report v2",
    author="AWS Cost Explorer",
)

story = []
story.append(Paragraph("AWS Monthly Cost Report v2", title_style))
story.append(
    Paragraph(
        "Combined report for agrovesto-dev and agrovesto-prod. "
        "Usage is shown before AWS credits; net is usage + credits + tax. "
        f"Generated {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}.",
        subtitle_style,
    )
)
story.append(Spacer(1, 4 * mm))

# ============================================================
# KPI CARDS
# ============================================================

cards = []
for label, value in [
    ("Previous Month Usage", previous_usage_total),
    ("Previous Month Net", previous_net_total),
    ("Current MTD Usage", current_usage_total),
    ("Month-End Usage Estimate", estimate_total),
]:
    card = Table(
        [
            [Paragraph(money(value), metric_style)],
            [Paragraph(label, label_style)],
        ],
        colWidths=[62 * mm],
        rowHeights=[11 * mm, 7 * mm],
    )
    card.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F3F4F6")),
                ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#D1D5DB")),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ]
        )
    )
    cards.append(card)

kpi_table = Table(
    [cards],
    colWidths=[65 * mm, 65 * mm, 65 * mm, 65 * mm],
)
kpi_table.setStyle(
    TableStyle(
        [
            ("LEFTPADDING", (0, 0), (-1, -1), 2),
            ("RIGHTPADDING", (0, 0), (-1, -1), 2),
        ]
    )
)
story.append(kpi_table)

# ============================================================
# ACCOUNT SUMMARY
# ============================================================

story.append(Paragraph("Account Summary", section_style))

account_data = [[
    P("Account", header_style),
    P("Previous Usage", header_style),
    P("Previous Credits", header_style),
    P("Previous Net", header_style),
    P("Current MTD Usage", header_style),
    P("Current Credits", header_style),
    P("Current Net", header_style),
    P("Month-End Usage Est.", header_style),
]]

for account in accounts:
    prev = previous_totals.get(account, {"usage": 0, "credit": 0, "tax": 0, "net": 0})
    curr = current_totals.get(
        account,
        {"usage": 0, "credit": 0, "tax": 0, "net": 0, "estimate": 0},
    )

    account_data.append([
        P(account),
        P(money(prev["usage"])),
        P(money(prev["credit"])),
        P(money(prev["net"])),
        P(money(curr["usage"])),
        P(money(curr["credit"])),
        P(money(curr["net"])),
        P(money(curr["estimate"])),
    ])

account_data.append([
    P("TOTAL"),
    P(money(previous_usage_total)),
    P(money(previous_credit_total)),
    P(money(previous_net_total)),
    P(money(current_usage_total)),
    P(money(current_credit_total)),
    P(money(current_net_total)),
    P(money(estimate_total)),
])

account_table = Table(
    account_data,
    colWidths=[
        40 * mm, 28 * mm, 28 * mm, 28 * mm,
        30 * mm, 28 * mm, 28 * mm, 33 * mm,
    ],
    repeatRows=1,
)
account_table.setStyle(
    TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#111827")),
            ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#D1D5DB")),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("ALIGN", (1, 1), (-1, -1), "RIGHT"),
            ("ROWBACKGROUNDS", (0, 1), (-1, -2), [colors.white, colors.HexColor("#F9FAFB")]),
            ("BACKGROUND", (0, -1), (-1, -1), colors.HexColor("#E5E7EB")),
            ("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"),
            ("TOPPADDING", (0, 0), (-1, -1), 3),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ]
    )
)
story.append(account_table)

# ============================================================
# SERVICE BREAKDOWN
# ============================================================

story.append(Paragraph("Service Cost Breakdown", section_style))

services = sorted(
    set(service_previous) | set(service_current),
    key=lambda s: (-max(service_previous[s], service_current[s]), s),
)

service_data = [[
    P("AWS Service", header_style),
    P("Previous Month Usage", header_style),
    P("Current MTD Usage", header_style),
    P("Month-End Usage Estimate", header_style),
]]

for service in services:
    prev = service_previous[service]
    curr = service_current[service]
    est = service_estimate[service]
    if prev == 0 and curr == 0:
        continue
    service_data.append([
        P(service),
        P(money(prev)),
        P(money(curr)),
        P(money(est)),
    ])

service_data.append([
    P("TOTAL"),
    P(money(previous_usage_total)),
    P(money(current_usage_total)),
    P(money(estimate_total)),
])

service_table = Table(
    service_data,
    colWidths=[95 * mm, 50 * mm, 50 * mm, 60 * mm],
    repeatRows=1,
)
service_table.setStyle(
    TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#111827")),
            ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#D1D5DB")),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("ALIGN", (1, 1), (-1, -1), "RIGHT"),
            ("ROWBACKGROUNDS", (0, 1), (-1, -2), [colors.white, colors.HexColor("#F9FAFB")]),
            ("BACKGROUND", (0, -1), (-1, -1), colors.HexColor("#E5E7EB")),
            ("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"),
            ("TOPPADDING", (0, 0), (-1, -1), 3),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ]
    )
)
story.append(service_table)

# ============================================================
# ACCOUNT + SERVICE DETAIL
# ============================================================

story.append(PageBreak())
story.append(Paragraph("Account / Service Detail", section_style))

detail_keys = sorted(
    set(account_service_previous) | set(account_service_current),
    key=lambda key: (-max(account_service_previous[key], account_service_current[key]), key[0], key[1]),
)

detail_data = [[
    P("Account", header_style),
    P("AWS Service", header_style),
    P("Previous Usage", header_style),
    P("Current MTD", header_style),
    P("Month-End Usage Est.", header_style),
]]

for account, service in detail_keys:
    prev = account_service_previous[(account, service)]
    curr = account_service_current[(account, service)]
    est = account_service_estimate[(account, service)]
    if prev == 0 and curr == 0:
        continue
    detail_data.append([
        P(account),
        P(service),
        P(money(prev)),
        P(money(curr)),
        P(money(est)),
    ])

detail_table = Table(
    detail_data,
    colWidths=[55 * mm, 90 * mm, 45 * mm, 45 * mm, 50 * mm],
    repeatRows=1,
)
detail_table.setStyle(
    TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#111827")),
            ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#D1D5DB")),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("ALIGN", (2, 1), (-1, -1), "RIGHT"),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F9FAFB")]),
            ("TOPPADDING", (0, 0), (-1, -1), 3),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ]
    )
)
story.append(detail_table)

# ============================================================
# CREDITS / TAX / NET
# ============================================================

story.append(PageBreak())
story.append(Paragraph("Credits, Tax and Net Cost", section_style))

credit_data = [[
    P("Account", header_style),
    P("Period", header_style),
    P("Usage", header_style),
    P("Credits", header_style),
    P("Tax", header_style),
    P("Net", header_style),
]]

for account in accounts:
    prev = previous_totals.get(account, {})
    curr = current_totals.get(account, {})

    credit_data.append([
        P(account),
        P("Previous Month"),
        P(money(prev.get("usage", 0))),
        P(money(prev.get("credit", 0))),
        P(money(prev.get("tax", 0))),
        P(money(prev.get("net", 0))),
    ])

    credit_data.append([
        P(account),
        P("Current MTD"),
        P(money(curr.get("usage", 0))),
        P(money(curr.get("credit", 0))),
        P(money(curr.get("tax", 0))),
        P(money(curr.get("net", 0))),
    ])

credit_table = Table(
    credit_data,
    colWidths=[55 * mm, 45 * mm, 40 * mm, 40 * mm, 35 * mm, 40 * mm],
    repeatRows=1,
)
credit_table.setStyle(
    TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#111827")),
            ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#D1D5DB")),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("ALIGN", (2, 1), (-1, -1), "RIGHT"),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F9FAFB")]),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]
    )
)
story.append(credit_table)
story.append(Spacer(1, 5 * mm))

story.append(
    Paragraph(
        "<b>Interpretation:</b> Usage is gross AWS consumption before credits. "
        "Credits are negative amounts and reduce the bill. Net equals Usage + Credits + Tax. "
        "Month-end estimates are simple linear run-rates from current MTD usage; they are not AWS forecasts.",
        cell_style,
    )
)

# ============================================================
# RAW CSV DETAIL
# ============================================================

story.append(PageBreak())
story.append(Paragraph("Raw Cost Explorer Rows", section_style))

raw_data = [[
    P("Account", header_style),
    P("Account ID", header_style),
    P("Period", header_style),
    P("Period Type", header_style),
    P("Service", header_style),
    P("Usage", header_style),
    P("Credit", header_style),
    P("Tax", header_style),
    P("Net", header_style),
    P("Month-End Est.", header_style),
]]

for row in rows:
    raw_data.append([
        P(row.get("account")),
        P(row.get("account_id")),
        P(row.get("period")),
        P(row.get("period_type")),
        P(row.get("service")),
        P(money(row.get("usage_usd"))),
        P(money(row.get("credit_usd"))),
        P(money(row.get("tax_usd"))),
        P(money(row.get("net_usd"))),
        P(money(row.get("estimated_month_end_usd"))),
    ])

raw_table = Table(
    raw_data,
    colWidths=[
        28 * mm, 34 * mm, 25 * mm, 36 * mm, 55 * mm,
        30 * mm, 30 * mm, 25 * mm, 30 * mm, 35 * mm,
    ],
    repeatRows=1,
)
raw_table.setStyle(
    TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#111827")),
            ("GRID", (0, 0), (-1, -1), 0.2, colors.HexColor("#D1D5DB")),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("ALIGN", (5, 1), (-1, -1), "RIGHT"),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F9FAFB")]),
            ("TOPPADDING", (0, 0), (-1, -1), 2),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
        ]
    )
)
story.append(raw_table)


def footer(canvas, doc):
    canvas.saveState()
    width, _ = landscape(A4)

    canvas.setStrokeColor(colors.HexColor("#D1D5DB"))
    canvas.line(10 * mm, 11 * mm, width - 10 * mm, 11 * mm)

    canvas.setFont("Helvetica", 6.5)
    canvas.setFillColor(colors.HexColor("#6B7280"))

    canvas.drawString(10 * mm, 7 * mm, "AWS Monthly Cost Report v2")
    canvas.drawCentredString(
        width / 2,
        7 * mm,
        "AWS Cost Explorer / UnblendedCost",
    )
    canvas.drawRightString(
        width - 10 * mm,
        7 * mm,
        f"Page {doc.page}",
    )

    canvas.restoreState()


doc.build(
    story,
    onFirstPage=footer,
    onLaterPages=footer,
)

print("=" * 60)
print("AWS COST PDF V2 GENERATED")
print("=" * 60)
print(f"Input : {INPUT_CSV}")
print(f"Output: {OUTPUT_PDF}")
print(f"Accounts: {len(accounts)}")
print(f"Previous month usage: {money(previous_usage_total)}")
print(f"Previous month credits: {money(previous_credit_total)}")
print(f"Previous month net: {money(previous_net_total)}")
print(f"Current MTD usage: {money(current_usage_total)}")
print(f"Current MTD credits: {money(current_credit_total)}")
print(f"Current MTD net: {money(current_net_total)}")
print(f"Month-end usage estimate: {money(estimate_total)}")
print("=" * 60)
