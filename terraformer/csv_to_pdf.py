#!/usr/bin/env python3

from pathlib import Path
import csv
from collections import Counter
from datetime import datetime

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
    KeepTogether,
)


# ============================================================
# PATHS
# ============================================================

BASE_DIR = Path(__file__).resolve().parent

CSV_FILE = BASE_DIR / "aws-inventory.csv"
PDF_FILE = BASE_DIR / "aws-inventory.pdf"


# ============================================================
# VALIDATION
# ============================================================

if not CSV_FILE.exists():
    raise SystemExit(
        f"\nERROR: Inventory CSV not found:\n{CSV_FILE}\n\n"
        "Run build_inventory.py first.\n"
    )


# ============================================================
# LOAD CSV
# ============================================================

with CSV_FILE.open(
    "r",
    newline="",
    encoding="utf-8",
) as f:
    reader = csv.DictReader(f)
    rows = list(reader)


if not rows:
    raise SystemExit(
        f"\nERROR: CSV is empty:\n{CSV_FILE}\n"
    )


# ============================================================
# NORMALIZATION
# ============================================================

def clean(value):
    if value is None:
        return ""

    return str(value).strip()


for row in rows:
    for key in row:
        row[key] = clean(row[key])


# ============================================================
# SUMMARY DATA
# ============================================================

accounts = sorted(
    {
        row.get("account", "")
        for row in rows
        if row.get("account", "")
    }
)

regions = sorted(
    {
        row.get("region", "")
        for row in rows
        if row.get("region", "")
        and row.get("region", "") != "unknown"
    }
)

services = sorted(
    {
        row.get("service", "")
        for row in rows
        if row.get("service", "")
    }
)

account_counts = Counter(
    row.get("account", "")
    for row in rows
    if row.get("account", "")
)

service_counts = Counter(
    (
        row.get("account", ""),
        row.get("service", ""),
    )
    for row in rows
    if row.get("account", "")
)

region_counts = Counter(
    (
        row.get("account", ""),
        row.get("region", ""),
    )
    for row in rows
    if row.get("account", "")
)

resource_type_counts = Counter(
    (
        row.get("service", ""),
        row.get("resource_type", ""),
    )
    for row in rows
)


def number(value):
    return f"{value:,}"


# ============================================================
# PDF STYLES
# ============================================================

styles = getSampleStyleSheet()

title_style = ParagraphStyle(
    "TitleCustom",
    parent=styles["Title"],
    fontName="Helvetica-Bold",
    fontSize=20,
    leading=24,
    alignment=TA_LEFT,
    spaceAfter=5 * mm,
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

cell_style = ParagraphStyle(
    "CellCustom",
    parent=styles["Normal"],
    fontName="Helvetica",
    fontSize=6,
    leading=7.5,
)

cell_small_style = ParagraphStyle(
    "CellSmall",
    parent=styles["Normal"],
    fontName="Helvetica",
    fontSize=5.5,
    leading=6.5,
)

table_header_style = ParagraphStyle(
    "TableHeader",
    parent=styles["Normal"],
    fontName="Helvetica-Bold",
    fontSize=6.5,
    leading=8,
    textColor=colors.white,
    alignment=TA_LEFT,
)

metric_value_style = ParagraphStyle(
    "MetricValue",
    parent=styles["Normal"],
    fontName="Helvetica-Bold",
    fontSize=18,
    leading=20,
    alignment=TA_CENTER,
)

metric_label_style = ParagraphStyle(
    "MetricLabel",
    parent=styles["Normal"],
    fontName="Helvetica",
    fontSize=7,
    leading=9,
    textColor=colors.HexColor("#4B5563"),
    alignment=TA_CENTER,
)


# ============================================================
# HELPERS
# ============================================================

def paragraph(value, small=False):
    style = cell_small_style if small else cell_style

    value = clean(value)

    if not value:
        value = "-"

    # Prevent accidental HTML interpretation.
    value = (
        value
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )

    return Paragraph(value, style)


def header(value):
    value = (
        clean(value)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )

    return Paragraph(value, table_header_style)


def add_table_style(table, total_row=None):
    commands = [
        (
            "BACKGROUND",
            (0, 0),
            (-1, 0),
            colors.HexColor("#111827"),
        ),
        (
            "TEXTCOLOR",
            (0, 0),
            (-1, 0),
            colors.white,
        ),
        (
            "FONTNAME",
            (0, 0),
            (-1, 0),
            "Helvetica-Bold",
        ),
        (
            "GRID",
            (0, 0),
            (-1, -1),
            0.25,
            colors.HexColor("#D1D5DB"),
        ),
        (
            "VALIGN",
            (0, 0),
            (-1, -1),
            "TOP",
        ),
        (
            "TOPPADDING",
            (0, 0),
            (-1, -1),
            3,
        ),
        (
            "BOTTOMPADDING",
            (0, 0),
            (-1, -1),
            3,
        ),
        (
            "LEFTPADDING",
            (0, 0),
            (-1, -1),
            3,
        ),
        (
            "RIGHTPADDING",
            (0, 0),
            (-1, -1),
            3,
        ),
        (
            "ROWBACKGROUNDS",
            (0, 1),
            (-1, -1),
            [
                colors.white,
                colors.HexColor("#F9FAFB"),
            ],
        ),
    ]

    if total_row is not None:
        commands.extend(
            [
                (
                    "BACKGROUND",
                    (0, total_row),
                    (-1, total_row),
                    colors.HexColor("#E5E7EB"),
                ),
                (
                    "FONTNAME",
                    (0, total_row),
                    (-1, total_row),
                    "Helvetica-Bold",
                ),
            ]
        )

    table.setStyle(TableStyle(commands))


def footer(canvas, doc):
    canvas.saveState()

    width, height = landscape(A4)

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
        "AWS Account Inventory",
    )

    canvas.drawCentredString(
        width / 2,
        7 * mm,
        "Generated from Terraformer inventory",
    )

    canvas.drawRightString(
        width - 10 * mm,
        7 * mm,
        f"Page {doc.page}",
    )

    canvas.restoreState()


# ============================================================
# DOCUMENT
# ============================================================

doc = SimpleDocTemplate(
    str(PDF_FILE),
    pagesize=landscape(A4),
    rightMargin=10 * mm,
    leftMargin=10 * mm,
    topMargin=10 * mm,
    bottomMargin=15 * mm,
    title="AWS Account Inventory",
    author="Terraformer Inventory",
)

story = []


# ============================================================
# TITLE
# ============================================================

story.append(
    Paragraph(
        "AWS Account Inventory",
        title_style,
    )
)

generated_at = datetime.now().strftime(
    "%Y-%m-%d %H:%M:%S"
)

story.append(
    Paragraph(
        (
            f"Combined inventory across {number(len(accounts))} AWS account(s) "
            f"and {number(len(regions))} discovered region(s). "
            f"Generated: {generated_at}"
        ),
        subtitle_style,
    )
)


# ============================================================
# KPI CARDS
# ============================================================

metrics = [
    ("Accounts", number(len(accounts))),
    ("Regions", number(len(regions))),
    ("Services", number(len(services))),
    ("Inventory Entries", number(len(rows))),
]

metric_data = []

for label, value in metrics:
    metric_data.append(
        [
            Paragraph(value, metric_value_style),
            Paragraph(label, metric_label_style),
        ]
    )

metric_tables = []

for label, value in metrics:
    metric_table = Table(
        [
            [Paragraph(value, metric_value_style)],
            [Paragraph(label, metric_label_style)],
        ],
        colWidths=[58 * mm],
        rowHeights=[12 * mm, 7 * mm],
    )

    metric_table.setStyle(
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

    metric_tables.append(metric_table)


kpi_row = Table(
    [metric_tables],
    colWidths=[
        64 * mm,
        64 * mm,
        64 * mm,
        64 * mm,
    ],
)

kpi_row.setStyle(
    TableStyle(
        [
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("LEFTPADDING", (0, 0), (-1, -1), 2),
            ("RIGHTPADDING", (0, 0), (-1, -1), 2),
        ]
    )
)

story.append(kpi_row)
story.append(Spacer(1, 5 * mm))


# ============================================================
# ACCOUNT SUMMARY
# ============================================================

story.append(
    Paragraph(
        "Account Summary",
        section_style,
    )
)

account_data = [
    [
        header("Account"),
        header("Inventory Entries"),
        header("Regions"),
        header("Services"),
    ]
]

for account in accounts:
    account_regions = {
        row.get("region", "")
        for row in rows
        if row.get("account", "") == account
        and row.get("region", "")
        and row.get("region", "") != "unknown"
    }

    account_services = {
        row.get("service", "")
        for row in rows
        if row.get("account", "") == account
        and row.get("service", "")
    }

    account_data.append(
        [
            paragraph(account),
            paragraph(number(account_counts[account])),
            paragraph(number(len(account_regions))),
            paragraph(number(len(account_services))),
        ]
    )

total_row = len(account_data)

account_data.append(
    [
        paragraph("TOTAL"),
        paragraph(number(len(rows))),
        paragraph(number(len(regions))),
        paragraph(number(len(services))),
    ]
)

account_table = Table(
    account_data,
    colWidths=[
        65 * mm,
        45 * mm,
        35 * mm,
        35 * mm,
    ],
    repeatRows=1,
)

add_table_style(account_table, total_row)

story.append(account_table)


# ============================================================
# REGION SUMMARY
# ============================================================

story.append(
    Paragraph(
        "Region Summary",
        section_style,
    )
)

region_data = [
    [
        header("Account"),
        header("Region"),
        header("Entries"),
    ]
]

for account in accounts:
    account_regions = sorted(
        {
            row.get("region", "")
            for row in rows
            if row.get("account", "") == account
            and row.get("region", "")
        }
    )

    for region in account_regions:
        region_data.append(
            [
                paragraph(account),
                paragraph(region),
                paragraph(
                    number(
                        region_counts[
                            (account, region)
                        ]
                    )
                ),
            ]
        )

region_table = Table(
    region_data,
    colWidths=[
        70 * mm,
        55 * mm,
        35 * mm,
    ],
    repeatRows=1,
)

add_table_style(region_table)

story.append(region_table)


# ============================================================
# SERVICE SUMMARY
# ============================================================

story.append(PageBreak())

story.append(
    Paragraph(
        "Service Summary",
        section_style,
    )
)

service_data = [
    [
        header("Account"),
        header("Service"),
        header("Entries"),
    ]
]

for (account, service), count in sorted(
    service_counts.items()
):
    service_data.append(
        [
            paragraph(account),
            paragraph(service),
            paragraph(number(count)),
        ]
    )

service_total_row = len(service_data)

service_data.append(
    [
        paragraph("TOTAL"),
        paragraph("All Services"),
        paragraph(number(len(rows))),
    ]
)

service_table = Table(
    service_data,
    colWidths=[
        65 * mm,
        75 * mm,
        35 * mm,
    ],
    repeatRows=1,
)

add_table_style(
    service_table,
    service_total_row,
)

story.append(service_table)


# ============================================================
# RESOURCE TYPE SUMMARY
# ============================================================

story.append(
    Paragraph(
        "Resource Type Summary",
        section_style,
    )
)

resource_type_data = [
    [
        header("Service"),
        header("Terraform Resource Type"),
        header("Entries"),
    ]
]

for (service, resource_type), count in sorted(
    resource_type_counts.items()
):
    resource_type_data.append(
        [
            paragraph(service),
            paragraph(resource_type),
            paragraph(number(count)),
        ]
    )

resource_type_total_row = len(
    resource_type_data
)

resource_type_data.append(
    [
        paragraph("TOTAL"),
        paragraph("All Resource Types"),
        paragraph(number(len(rows))),
    ]
)

resource_type_table = Table(
    resource_type_data,
    colWidths=[
        65 * mm,
        90 * mm,
        35 * mm,
    ],
    repeatRows=1,
)

add_table_style(
    resource_type_table,
    resource_type_total_row,
)

story.append(resource_type_table)


# ============================================================
# DETAILED INVENTORY
# ============================================================

story.append(PageBreak())

story.append(
    Paragraph(
        "Detailed Resource Inventory",
        section_style,
    )
)

columns = [
    "account",
    "region",
    "service",
    "terraform_type",
    "resource_type",
    "resource_name",
    "name",
    "id",
    "arn",
    "file",
]

headers = [
    "Account",
    "Region",
    "Service",
    "Type",
    "Resource",
    "Terraform Name",
    "Name",
    "ID",
    "ARN",
    "Source File",
]

detail_data = [
    [header(h) for h in headers]
]


for row in rows:
    detail_data.append(
        [
            paragraph(
                row.get("account", "")
            ),

            paragraph(
                row.get("region", "")
            ),

            paragraph(
                row.get("service", "")
            ),

            paragraph(
                row.get("terraform_type", "")
            ),

            paragraph(
                row.get("resource_type", ""),
                small=True,
            ),

            paragraph(
                row.get("resource_name", ""),
                small=True,
            ),

            paragraph(
                row.get("name", ""),
                small=True,
            ),

            paragraph(
                row.get("id", ""),
                small=True,
            ),

            paragraph(
                row.get("arn", ""),
                small=True,
            ),

            paragraph(
                row.get("file", ""),
                small=True,
            ),
        ]
    )


detail_table = Table(
    detail_data,
    colWidths=[
        26 * mm,  # account
        18 * mm,  # region
        21 * mm,  # service
        15 * mm,  # terraform type
        27 * mm,  # resource type
        31 * mm,  # resource name
        27 * mm,  # name
        29 * mm,  # id
        43 * mm,  # arn
        50 * mm,  # file
    ],
    repeatRows=1,
)

add_table_style(detail_table)

story.append(detail_table)


# ============================================================
# BUILD PDF
# ============================================================

doc.build(
    story,
    onFirstPage=footer,
    onLaterPages=footer,
)


print()
print("=" * 60)
print("AWS INVENTORY PDF GENERATED")
print("=" * 60)
print()
print(f"Source CSV : {CSV_FILE}")
print(f"Output PDF : {PDF_FILE}")
print(f"Accounts   : {len(accounts):,}")
print(f"Regions    : {len(regions):,}")
print(f"Services   : {len(services):,}")
print(f"Entries    : {len(rows):,}")
print()
