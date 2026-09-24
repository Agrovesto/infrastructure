#!/usr/bin/env python3

from pathlib import Path
import csv
from collections import defaultdict
from datetime import datetime

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER
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

INPUT_CSV = BASE_DIR / "aws-cost-report.csv"
OUTPUT_PDF = BASE_DIR / "aws-cost-report.pdf"


if not INPUT_CSV.exists():
    raise SystemExit(
        f"ERROR: {INPUT_CSV} was not found.\n"
        "Run aws_cost_report.py first."
    )


# ============================================================
# LOAD CSV
# ============================================================

with INPUT_CSV.open(
    "r",
    newline="",
    encoding="utf-8",
) as f:
    rows = list(csv.DictReader(f))


if not rows:
    raise SystemExit("ERROR: aws-cost-report.csv is empty.")


def money(value):
    try:
        return f"${float(value):,.2f}"
    except (ValueError, TypeError):
        return "$0.00"


def safe_float(value):
    try:
        return float(value)
    except (ValueError, TypeError):
        return 0.0


def P(text, style):
    text = str(text or "-")

    text = (
        text
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )

    return Paragraph(text, style)


# ============================================================
# STYLES
# ============================================================

styles = getSampleStyleSheet()

title_style = ParagraphStyle(
    "TitleCustom",
    parent=styles["Title"],
    fontName="Helvetica-Bold",
    fontSize=20,
    leading=24,
    alignment=TA_LEFT,
    spaceAfter=4 * mm,
)

subtitle_style = ParagraphStyle(
    "SubtitleCustom",
    parent=styles["Normal"],
    fontName="Helvetica",
    fontSize=8,
    leading=11,
    textColor=colors.HexColor("#4B5563"),
    spaceAfter=5 * mm,
)

section_style = ParagraphStyle(
    "SectionCustom",
    parent=styles["Heading2"],
    fontName="Helvetica-Bold",
    fontSize=12,
    leading=15,
    textColor=colors.HexColor("#111827"),
    spaceBefore=4 * mm,
    spaceAfter=3 * mm,
)

header_style = ParagraphStyle(
    "HeaderCustom",
    parent=styles["Normal"],
    fontName="Helvetica-Bold",
    fontSize=6.5,
    leading=8,
    textColor=colors.white,
)

cell_style = ParagraphStyle(
    "CellCustom",
    parent=styles["Normal"],
    fontName="Helvetica",
    fontSize=6.5,
    leading=8,
)

small_cell_style = ParagraphStyle(
    "SmallCellCustom",
    parent=styles["Normal"],
    fontName="Helvetica",
    fontSize=5.5,
    leading=6.5,
)

big_money_style = ParagraphStyle(
    "BigMoney",
    parent=styles["Normal"],
    fontName="Helvetica-Bold",
    fontSize=17,
    leading=20,
    alignment=TA_CENTER,
)

metric_label_style = ParagraphStyle(
    "MetricLabel",
    parent=styles["Normal"],
    fontName="Helvetica",
    fontSize=7,
    leading=9,
    alignment=TA_CENTER,
    textColor=colors.HexColor("#4B5563"),
)


# ============================================================
# SUMMARY CALCULATIONS
# ============================================================

actual_rows = [
    r
    for r in rows
    if r.get("period_type") in {
        "previous_month_actual",
        "current_month_mtd",
    }
]

previous_rows = [
    r
    for r in rows
    if r.get("period_type") == "previous_month_actual"
]

mtd_rows = [
    r
    for r in rows
    if r.get("period_type") == "current_month_mtd"
]

forecast_rows = [
    r
    for r in rows
    if r.get("period_type") == "current_month_forecast_total"
]


accounts = sorted(
    {
        r.get("account", "")
        for r in rows
        if r.get("account", "")
    }
)


previous_by_account = defaultdict(float)
mtd_by_account = defaultdict(float)
forecast_by_account = defaultdict(float)

previous_by_service = defaultdict(float)
mtd_by_service = defaultdict(float)

previous_account_service = defaultdict(float)
mtd_account_service = defaultdict(float)


for r in previous_rows:
    account = r.get("account", "")
    service = r.get("service", "")

    cost = safe_float(r.get("cost_usd"))

    previous_by_account[account] += cost
    previous_by_service[service] += cost
    previous_account_service[(account, service)] += cost


for r in mtd_rows:
    account = r.get("account", "")
    service = r.get("service", "")

    cost = safe_float(r.get("cost_usd"))

    mtd_by_account[account] += cost
    mtd_by_service[service] += cost
    mtd_account_service[(account, service)] += cost


for r in forecast_rows:
    forecast_by_account[
        r.get("account", "")
    ] += safe_float(r.get("cost_usd"))


previous_total = sum(previous_by_account.values())
mtd_total = sum(mtd_by_account.values())
forecast_total = sum(forecast_by_account.values())


# ============================================================
# DOCUMENT
# ============================================================

doc = SimpleDocTemplate(
    str(OUTPUT_PDF),
    pagesize=landscape(A4),
    rightMargin=10 * mm,
    leftMargin=10 * mm,
    topMargin=10 * mm,
    bottomMargin=15 * mm,
    title="AWS Cost Report",
    author="AWS Cost Explorer",
)


story = []


# ============================================================
# TITLE
# ============================================================

generated_at = datetime.now().strftime(
    "%Y-%m-%d %H:%M:%S"
)

story.append(
    Paragraph(
        "AWS Monthly Cost Report",
        title_style,
    )
)

story.append(
    Paragraph(
        f"Combined AWS Cost Explorer report | "
        f"Accounts: {len(accounts)} | "
        f"Generated: {generated_at}",
        subtitle_style,
    )
)


# ============================================================
# KPI CARDS
# ============================================================

kpis = [
    ("Previous Month", money(previous_total)),
    ("Current MTD", money(mtd_total)),
    ("Current Forecast", money(forecast_total)),
]


cards = []

for label, value in kpis:
    card = Table(
        [
            [Paragraph(value, big_money_style)],
            [Paragraph(label, metric_label_style)],
        ],
        colWidths=[78 * mm],
        rowHeights=[13 * mm, 7 * mm],
    )

    card.setStyle(
        TableStyle(
            [
                (
                    "BACKGROUND",
                    (0, 0),
                    (-1, -1),
                    colors.HexColor("#F3F4F6"),
                ),
                (
                    "BOX",
                    (0, 0),
                    (-1, -1),
                    0.5,
                    colors.HexColor("#D1D5DB"),
                ),
                (
                    "VALIGN",
                    (0, 0),
                    (-1, -1),
                    "MIDDLE",
                ),
            ]
        )
    )

    cards.append(card)


kpi_table = Table(
    [cards],
    colWidths=[
        82 * mm,
        82 * mm,
        82 * mm,
    ],
)

kpi_table.setStyle(
    TableStyle(
        [
            (
                "LEFTPADDING",
                (0, 0),
                (-1, -1),
                2,
            ),
            (
                "RIGHTPADDING",
                (0, 0),
                (-1, -1),
                2,
            ),
        ]
    )
)

story.append(kpi_table)
story.append(Spacer(1, 5 * mm))


# ============================================================
# ACCOUNT SUMMARY
# ============================================================

story.append(
    Paragraph(
        "Cost by Account",
        section_style,
    )
)

account_data = [
    [
        P("Account", header_style),
        P("Previous Month", header_style),
        P("Current MTD", header_style),
        P("Current Forecast", header_style),
    ]
]

for account in accounts:
    account_data.append(
        [
            P(account, cell_style),
            P(money(previous_by_account[account]), cell_style),
            P(money(mtd_by_account[account]), cell_style),
            P(money(forecast_by_account[account]), cell_style),
        ]
    )


account_total_row = len(account_data)

account_data.append(
    [
        P("TOTAL", cell_style),
        P(money(previous_total), cell_style),
        P(money(mtd_total), cell_style),
        P(money(forecast_total), cell_style),
    ]
)


account_table = Table(
    account_data,
    colWidths=[
        70 * mm,
        50 * mm,
        50 * mm,
        50 * mm,
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
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            (
                "BACKGROUND",
                (0, account_total_row),
                (-1, account_total_row),
                colors.HexColor("#E5E7EB"),
            ),
            (
                "FONTNAME",
                (0, account_total_row),
                (-1, account_total_row),
                "Helvetica-Bold",
            ),
        ]
    )
)

story.append(account_table)


# ============================================================
# SERVICE SUMMARY
# ============================================================

story.append(
    Paragraph(
        "Cost by AWS Service",
        section_style,
    )
)

services = sorted(
    set(previous_by_service.keys())
    | set(mtd_by_service.keys())
)

service_data = [
    [
        P("Service", header_style),
        P("Previous Month", header_style),
        P("Current MTD", header_style),
    ]
]

for service in services:
    service_data.append(
        [
            P(service, cell_style),
            P(money(previous_by_service[service]), cell_style),
            P(money(mtd_by_service[service]), cell_style),
        ]
    )


service_total_row = len(service_data)

service_data.append(
    [
        P("TOTAL", cell_style),
        P(money(previous_total), cell_style),
        P(money(mtd_total), cell_style),
    ]
)


service_table = Table(
    service_data,
    colWidths=[
        100 * mm,
        55 * mm,
        55 * mm,
    ],
    repeatRows=1,
)


service_table.setStyle(
    TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#111827")),
            ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#D1D5DB")),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("ALIGN", (1, 1), (-1, -1), "RIGHT"),
            ("TOPPADDING", (0, 0), (-1, -1), 3),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
            (
                "BACKGROUND",
                (0, service_total_row),
                (-1, service_total_row),
                colors.HexColor("#E5E7EB"),
            ),
            (
                "FONTNAME",
                (0, service_total_row),
                (-1, service_total_row),
                "Helvetica-Bold",
            ),
        ]
    )
)

story.append(service_table)


# ============================================================
# ACCOUNT + SERVICE DETAIL
# ============================================================

story.append(PageBreak())

story.append(
    Paragraph(
        "Account and Service Cost Detail",
        section_style,
    )
)

detail_keys = sorted(
    set(previous_account_service.keys())
    | set(mtd_account_service.keys())
)

detail_data = [
    [
        P("Account", header_style),
        P("AWS Service", header_style),
        P("Previous Month", header_style),
        P("Current MTD", header_style),
    ]
]

for account, service in detail_keys:
    detail_data.append(
        [
            P(account, cell_style),
            P(service, cell_style),
            P(
                money(
                    previous_account_service[
                        (account, service)
                    ]
                ),
                cell_style,
            ),
            P(
                money(
                    mtd_account_service[
                        (account, service)
                    ]
                ),
                cell_style,
            ),
        ]
    )


detail_table = Table(
    detail_data,
    colWidths=[
        65 * mm,
        90 * mm,
        50 * mm,
        50 * mm,
    ],
    repeatRows=1,
)

detail_table.setStyle(
    TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#111827")),
            ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#D1D5DB")),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("ALIGN", (2, 1), (-1, -1), "RIGHT"),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [
                colors.white,
                colors.HexColor("#F9FAFB"),
            ]),
            ("TOPPADDING", (0, 0), (-1, -1), 3),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ]
    )
)

story.append(detail_table)


# ============================================================
# RAW COST DATA
# ============================================================

story.append(PageBreak())

story.append(
    Paragraph(
        "Cost Explorer Detail",
        section_style,
    )
)

raw_headers = [
    "Account",
    "Account ID",
    "Period",
    "Period Type",
    "Service",
    "Cost USD",
]

raw_data = [
    [P(h, header_style) for h in raw_headers]
]

for row in rows:
    raw_data.append(
        [
            P(row.get("account"), small_cell_style),
            P(row.get("account_id"), small_cell_style),
            P(row.get("period"), small_cell_style),
            P(row.get("period_type"), small_cell_style),
            P(row.get("service"), small_cell_style),
            P(money(row.get("cost_usd")), small_cell_style),
        ]
    )


raw_table = Table(
    raw_data,
    colWidths=[
        45 * mm,
        35 * mm,
        27 * mm,
        45 * mm,
        60 * mm,
        30 * mm,
    ],
    repeatRows=1,
)


raw_table.setStyle(
    TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#111827")),
            ("GRID", (0, 0), (-1, -1), 0.2, colors.HexColor("#D1D5DB")),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("ALIGN", (5, 1), (5, -1), "RIGHT"),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [
                colors.white,
                colors.HexColor("#F9FAFB"),
            ]),
            ("TOPPADDING", (0, 0), (-1, -1), 2),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
        ]
    )
)

story.append(raw_table)


# ============================================================
# FOOTER
# ============================================================

def footer(canvas, doc):
    canvas.saveState()

    width, _ = landscape(A4)

    canvas.setStrokeColor(
        colors.HexColor("#D1D5DB")
    )

    canvas.line(
        10 * mm,
        11 * mm,
        width - 10 * mm,
        11 * mm,
    )

    canvas.setFont(
        "Helvetica",
        6.5,
    )

    canvas.setFillColor(
        colors.HexColor("#6B7280")
    )

    canvas.drawString(
        10 * mm,
        7 * mm,
        "AWS Cost Report",
    )

    canvas.drawCentredString(
        width / 2,
        7 * mm,
        "Source: AWS Cost Explorer via AWS CLI",
    )

    canvas.drawRightString(
        width - 10 * mm,
        7 * mm,
        f"Page {doc.page}",
    )

    canvas.restoreState()


# ============================================================
# GENERATE
# ============================================================

doc.build(
    story,
    onFirstPage=footer,
    onLaterPages=footer,
)

print()
print("=" * 60)
print("AWS COST PDF GENERATED")
print("=" * 60)
print(f"Input : {INPUT_CSV}")
print(f"Output: {OUTPUT_PDF}")
print(f"Accounts: {len(accounts)}")
print(f"Previous month: {money(previous_total)}")
print(f"Current MTD:    {money(mtd_total)}")
print(f"Forecast:       {money(forecast_total)}")
print("=" * 60)
print()
