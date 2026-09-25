#!/usr/bin/env python3
"""Print one cost report from an Infracost breakdown plus the unpriceable extras.

    python3 scripts/infracost_summary.py .infracost/breakdown.json

Two sources are merged:

* the Infracost breakdown JSON (`infracost breakdown --config-file infracost.yml
  --format json --out-file ...`), one line per project;
* `infracost-extras.json`, the monthly costs Infracost cannot see because no
  priced resource describes them (Fargate batch tasks, Cloud Map, public IPv4,
  egress, Amplify, SES, schedulers).

The combined figure is the honest bottom line: Infracost alone understates this
stack by roughly $19/month.
"""

from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def to_float(value, default=0.0):
    if value in (None, "", "null"):
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def money(value):
    return f"${value:,.2f}"


def load_json(path, what):
    try:
        return json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    except FileNotFoundError:
        sys.exit(f"{what} not found: {path}")
    except json.JSONDecodeError as exc:
        sys.exit(f"{what} is not valid JSON ({path}): {exc}")


def project_rows(breakdown):
    rows = []
    for project in breakdown.get("projects", []):
        detail = project.get("breakdown") or {}
        name = project.get("name") or (project.get("metadata") or {}).get("path") or "unnamed project"
        monthly = to_float(detail.get("totalMonthlyCost", project.get("totalMonthlyCost")))
        past = detail.get("pastTotalMonthlyCost", project.get("pastTotalMonthlyCost"))
        delta = None
        if past not in (None, ""):
            delta = monthly - to_float(past)
        skipped = 0
        for resource in detail.get("resources", []) or []:
            if resource.get("isSkipped") or resource.get("noPrice") or resource.get("skipReason"):
                skipped += 1
        rows.append((name, monthly, delta, skipped))
    return rows


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)

    breakdown = load_json(sys.argv[1], "Infracost breakdown")
    extras = load_json(ROOT / "infracost-extras.json", "extras ledger")

    currency = breakdown.get("currency", extras.get("currency", "USD"))
    rows = project_rows(breakdown)
    infracost_total = to_float(breakdown.get("totalMonthlyCost"), sum(r[1] for r in rows))

    width = max([len(r[0]) for r in rows] + [30])
    print()
    print(f"Infracost — every stack in this repository ({currency}, eu-west-1 list price)")
    print("-" * (width + 30))
    for name, monthly, delta, skipped in rows:
        note = ""
        if skipped:
            note = f"  ({skipped} unpriced resource(s), see --show-skipped)"
        if monthly == 0.0:
            note += "  <- no priceable resource found, check the Infracost output above"
        print(f"{name:<{width}}  {money(monthly):>12}{note}")
    print("-" * (width + 30))
    print(f"{'Infracost subtotal':<{width}}  {money(infracost_total):>12}")

    items = extras.get("items", [])
    item_width = max([len(item.get("name", "")) for item in items] + [30])
    print()
    print("Costs Infracost cannot price (infracost-extras.json)")
    print("-" * (item_width + 14))
    for item in items:
        print(f"{item.get('name', '?'):<{item_width}}  {money(to_float(item.get('monthly_usd'))):>12}")
    extras_total = sum(to_float(item.get("monthly_usd")) for item in items)
    print("-" * (item_width + 14))
    print(f"{'Extras subtotal':<{item_width}}  {money(extras_total):>12}")

    print()
    print(f"{'Combined monthly estimate':<{item_width}}  {money(infracost_total + extras_total):>12}")
    print()
    print("Usage assumptions live in infracost-usage/*.yml — edit them there and re-run.")
    print("Infracost prices Fargate at on-demand rates: with use_fargate_spot = true")
    print("the monitoring services are spot, which is a discount, not a cost.")


if __name__ == "__main__":
    main()
