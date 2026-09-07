#!/usr/bin/env python3
"""Require real, successful results from every configured Checkov framework."""
import argparse
import json
from pathlib import Path
import sys

FRAMEWORKS = {"terraform", "dockerfile", "github_actions"}


def check_report(report):
    reports = report if isinstance(report, list) else [report]
    seen, errors, lines = set(), [], []
    for item in reports:
        framework = item.get("check_type")
        summary = item.get("summary", {})
        if framework not in FRAMEWORKS:
            continue
        seen.add(framework)
        lines.append(f"{framework}: {summary.get('passed', 0)} passed, {summary.get('failed', 0)} failed, {summary.get('skipped', 0)} skipped")
        if summary.get("passed", 0) == 0:
            errors.append(f"{framework}: no passing checks; a schema/discovery error may have silently skipped this framework")
        if summary.get("failed", 0) or summary.get("parsing_errors", 0):
            errors.append(f"{framework}: failed checks or parsing errors")
        for finding in item.get("results", {}).get("failed_checks", []):
            errors.append(f"{finding['check_id']}: {finding.get('resource', 'resource')} ({finding.get('file_path', '')})")
    errors.extend(f"Missing Checkov framework: {framework}" for framework in sorted(FRAMEWORKS - seen))
    return lines, errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path, nargs="+", help="One or more Checkov JSON reports")
    args = parser.parse_args()
    reports = []
    for path in args.report:
        report = json.loads(path.read_text())
        reports.extend(report if isinstance(report, list) else [report])
    lines, errors = check_report(reports)
    print("\n".join(lines))
    if errors:
        print("\n".join(errors), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
