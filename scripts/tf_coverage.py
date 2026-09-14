#!/usr/bin/env python3
"""Terraform resource coverage.

`terraform test` tells you whether the suite passes. It does not tell you how
much of the module the suite actually touches. This script answers that.

WHAT IT MEASURES
----------------

For a Terraform root module:

  * "blocks"   = every top-level `resource` and `data` block declared in the
                 module's own *.tf files (the tests/ directory is excluded --
                 `override_resource`/`command` blocks there are not the thing
                 under test).
  * "covered"  = a block is covered when at least one *.tftest.hcl file in the
                 module's tests/ directory refers to it by address
                 (`<type>.<name>`, e.g. `aws_vpc.main`).

  coverage = covered blocks / total blocks

A reference anywhere in a test file counts, whether it appears in an
`assert` condition, an `override_resource` block or a `variables` map. That is
deliberate and slightly generous: it means the number answers "does the suite
know about this resource at all", not "is every argument of this resource
asserted". Treat it as a floor and a trend, not as a claim of exhaustiveness.

It is a static measure, so it needs no `terraform` binary and no AWS
credentials. Pass `--test-json` to also fold in the real `terraform test -json`
result and fail if the suite did not actually pass.

USAGE
-----

    tf_coverage.py <module-dir> [--json out.json] [--fail-under 60]
                              [--test-json test-results.json]
                              [--summary-md out.md]

Exit codes:
    0  ok (and >= fail-under, and the test suite passed if --test-json given)
    1  coverage below the threshold, or the test suite failed
    2  usage / input error
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

# Matches a top-level `resource "type" "name" {` / `data "type" "name" {` header.
BLOCK_RE = re.compile(
    r'^(?P<kind>resource|data)\s+"(?P<type>[A-Za-z0-9_-]+)"\s+"(?P<name>[A-Za-z0-9_-]+)"',
    re.MULTILINE,
)


def strip_comments(text: str) -> str:
    """Blank out `#`/`//` line comments and `/* */` block comments.

    Kept conservative: it understands quoted strings well enough not to eat a
    `#` inside one, and leaves everything else untouched.
    """
    out: list[str] = []
    i, n = 0, len(text)
    in_str = False
    in_block_comment = False
    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""

        if in_block_comment:
            if ch == "*" and nxt == "/":
                in_block_comment = False
                out.append("  ")
                i += 2
                continue
            out.append("\n" if ch == "\n" else " ")
            i += 1
            continue

        if in_str:
            out.append(ch)
            if ch == "\\":
                if nxt:
                    out.append(nxt)
                    i += 2
                    continue
            elif ch == '"':
                in_str = False
            i += 1
            continue

        if ch == '"':
            in_str = True
            out.append(ch)
            i += 1
            continue
        if ch == "#" or (ch == "/" and nxt == "/"):
            while i < n and text[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if ch == "/" and nxt == "*":
            in_block_comment = True
            out.append("  ")
            i += 2
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def collect_blocks(module_dir: str) -> dict[str, list[dict]]:
    """Return {relative .tf path: [block, ...]} for the module's own sources."""
    by_file: dict[str, list[dict]] = {}
    for root, dirs, files in os.walk(module_dir):
        # tests/ holds the suite, not the module under test.
        dirs[:] = sorted(d for d in dirs if d not in {"tests", ".terraform"})
        for name in sorted(files):
            if not name.endswith(".tf"):
                continue
            path = os.path.join(root, name)
            rel = os.path.relpath(path, module_dir)
            text = strip_comments(_read(path))
            blocks = []
            for match in BLOCK_RE.finditer(text):
                blocks.append(
                    {
                        "kind": match.group("kind"),
                        "type": match.group("type"),
                        "name": match.group("name"),
                        "address": "%s.%s" % (match.group("type"), match.group("name")),
                        "file": rel,
                        "line": text[: match.start()].count("\n") + 1,
                    }
                )
            by_file[rel] = blocks
    return by_file


def collect_test_text(module_dir: str) -> str:
    """Concatenate every *.tftest.hcl under <module_dir>/tests."""
    tests_dir = os.path.join(module_dir, "tests")
    if not os.path.isdir(tests_dir):
        return ""
    chunks = []
    for name in sorted(os.listdir(tests_dir)):
        if name.endswith(".tftest.hcl"):
            chunks.append(strip_comments(_read(os.path.join(tests_dir, name))))
    return "\n".join(chunks)


def _read(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def read_test_json(path: str) -> dict:
    """Summarise the output of `terraform test -json`.

    Returns {"passed": bool, "files": int, "runs": int, "failed": int,
             "error": str, "runs_list": list[dict]}. Terraform emits one JSON object per line.
    """
    result = {"passed": False, "files": 0, "runs": 0, "failed": 0, "error": "", "runs_list": []}
    runs_by_key = {}
    test_files_seen = set()

    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            kind = entry.get("type")
            if kind == "test_file":
                tf_path = entry.get("test_file", {}).get("path", "")
                if tf_path and tf_path not in test_files_seen:
                    test_files_seen.add(tf_path)
            elif kind == "test_run":
                tr = entry.get("test_run", {})
                path_val = tr.get("path", "")
                run_val = tr.get("run", "")
                status = tr.get("status") or entry.get("status", "")
                if path_val and run_val:
                    key = (path_val, run_val)
                    if key not in runs_by_key:
                        runs_by_key[key] = {"path": path_val, "run": run_val, "status": "unknown"}
                    if status:
                        runs_by_key[key]["status"] = status
            elif kind == "test_summary":
                status = entry.get("status", "")
                result["passed"] = status in ("pass", "skip")
                if status in ("fail", "error"):
                    result["error"] = entry.get("diagnostic", {}).get("summary", "") or "Test suite failed"

    result["files"] = len(test_files_seen)
    result["runs_list"] = list(runs_by_key.values())
    result["runs"] = len(result["runs_list"])
    result["failed"] = sum(1 for r in result["runs_list"] if r["status"] in ("fail", "error"))
    return result


def compute(module_dir: str) -> dict:
    by_file = collect_blocks(module_dir)
    test_text = collect_test_text(module_dir)

    files = []
    total = covered = 0
    for rel in sorted(by_file):
        blocks = by_file[rel]
        hits = [b for b in blocks if re.search(_addr_pattern(b["address"]), test_text)]
        hit_addresses = {b["address"] for b in hits}
        total += len(blocks)
        covered += len(hits)
        files.append(
            {
                "file": rel,
                "total": len(blocks),
                "covered": len(hits),
                "percent": _pct(len(hits), len(blocks)),
                "uncovered": [b["address"] for b in blocks if b["address"] not in hit_addresses],
            }
        )

    return {
        "module": module_dir,
        "files": files,
        "total_blocks": total,
        "covered_blocks": covered,
        "percent": _pct(covered, total),
    }


def _addr_pattern(address: str) -> str:
    """`aws_vpc.main` -> a regex matching that address on a word boundary.

    Matches both `aws_vpc.main` and the canonical data form
    `data.aws_vpc.main`. The lookarounds stop `aws_vpc.main` from matching
    inside `aws_vpc_endpoint.main` or `xaws_vpc.main`, while still allowing
    `aws_vpc.main.id` and `aws_vpc.main[0]`.
    """
    return r"(?<![\w-])(?:data\.)?%s(?![\w-])" % re.escape(address)


def _pct(part: int, whole: int) -> float:
    if not whole:
        return 0.0
    return round(100.0 * part / whole, 1)


def render_markdown(report: dict, fail_under: float, test_summary: dict | None) -> str:
    lines = ["## Terraform Test Suite & Coverage", ""]

    if test_summary is not None:
        state = "PASS" if test_summary["passed"] else "FAIL"
        lines.append(
            "### Test Suite Checks (`terraform test`): **%s** (%d test file(s), %d test run(s))"
            % (state, test_summary["files"], test_summary["runs"])
        )
        if not test_summary["passed"] and test_summary["error"]:
            lines.append("")
            lines.append("> ⚠️ %s" % test_summary["error"])
        lines.append("")

        if test_summary.get("runs_list"):
            lines.append("| Test File | Test Run | Status |")
            lines.append("| --- | --- | --- |")
            for item in test_summary["runs_list"]:
                status_icon = "✅ PASS" if item["status"] in ("pass", "skip") else "❌ FAIL"
                lines.append("| `%s` | `%s` | %s |" % (item["path"], item["run"], status_icon))
            lines.append("")

    lines += [
        "### Resource Coverage",
        "",
        "**Resource coverage: %s%%** (%d of %d `resource`/`data` blocks referenced "
        "by the suite)" % (report["percent"], report["covered_blocks"], report["total_blocks"]),
        "",
        "Threshold: **%s%%** -> %s"
        % (fail_under, "PASS" if report["percent"] >= fail_under else "FAIL"),
        "",
        "| File | Blocks | Covered | Coverage |",
        "| --- | --- | --- | --- |",
    ]

    for row in report["files"]:
        if not row["total"]:
            continue
        lines.append(
            "| `%s` | %d | %d | %s%% |"
            % (row["file"], row["total"], row["covered"], row["percent"])
        )

    gaps = [r for r in report["files"] if r["uncovered"]]
    if gaps:
        lines += ["", "<details><summary>Uncovered blocks</summary>", ""]
        for row in gaps:
            lines.append("- `%s`: %s" % (row["file"], ", ".join("`%s`" % a for a in row["uncovered"])))
        lines += ["", "</details>"]

    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("module_dir", help="Terraform root module, e.g. prod")
    parser.add_argument("--fail-under", type=float, default=0.0, metavar="PERCENT")
    parser.add_argument("--json", dest="json_out", metavar="PATH")
    parser.add_argument("--summary-md", dest="summary_md", metavar="PATH")
    parser.add_argument(
        "--test-json",
        dest="test_json",
        metavar="PATH",
        help="output of `terraform test -json`; fails the run if the suite failed",
    )
    args = parser.parse_args(argv)

    if not os.path.isdir(args.module_dir):
        print("::error::no such directory: %s" % args.module_dir, file=sys.stderr)
        return 2

    test_summary = None
    if args.test_json:
        if not os.path.isfile(args.test_json):
            print("::error::no such file: %s" % args.test_json, file=sys.stderr)
            return 2
        test_summary = read_test_json(args.test_json)

    report = compute(args.module_dir)
    report["test"] = test_summary

    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as fh:
            json.dump(report, fh, indent=2, sort_keys=True)
            fh.write("\n")

    markdown = render_markdown(report, args.fail_under, test_summary)
    if args.summary_md:
        with open(args.summary_md, "w", encoding="utf-8") as fh:
            fh.write(markdown)
    print(markdown)

    if test_summary is not None and not test_summary["passed"]:
        print(
            "::error::terraform test reported failures; coverage is meaningless "
            "until the suite passes."
        )
        return 1

    if report["total_blocks"] == 0:
        print("::error::found no resource/data blocks in %s" % args.module_dir, file=sys.stderr)
        return 2

    if report["percent"] < args.fail_under:
        print(
            "::error::resource coverage %s%% is below the %s%% threshold."
            % (report["percent"], args.fail_under)
        )
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
