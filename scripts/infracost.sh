#!/usr/bin/env bash
# Cost every stack in this repo, locally, in one command:
#
#   ./scripts/infracost.sh
#
# Runs Infracost over infracost.yml (bootstrap, dev, prod, monitoring), writes
# the raw JSON to .infracost/breakdown.json, prints Infracost's own table and
# then scripts/infracost_summary.py adds the costs Infracost cannot price
# (infracost-extras.json) for one combined monthly figure.
#
# Needs the Infracost CLI and a free API key:
#
#   brew install infracost
#   export INFRACOST_API_KEY=ico-...
#
# No AWS credentials are needed: Infracost reads the HCL and the public price
# list instead of calling AWS.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT_DIR=".infracost"
JSON="$OUT_DIR/breakdown.json"

if ! command -v infracost >/dev/null 2>&1; then
  echo "infracost CLI not found." >&2
  echo "  brew install infracost" >&2
  echo "  curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh" >&2
  exit 1
fi

if [[ -z "${INFRACOST_API_KEY:-}" ]]; then
  echo "INFRACOST_API_KEY is not set. Create a free key at https://dashboard.infracost.io" >&2
  echo "then: export INFRACOST_API_KEY=ico-..." >&2
  exit 1
fi

# The CLI renamed the command in newer releases; both understand infracost.yml.
if infracost breakdown --help >/dev/null 2>&1; then
  CMD="breakdown"
elif infracost scan --help >/dev/null 2>&1; then
  CMD="scan"
else
  echo "This infracost CLI has neither 'breakdown' nor 'scan'." >&2
  exit 1
fi

ARGS=(--config-file infracost.yml --no-color --format json --out-file "$JSON")
if infracost "$CMD" --help 2>&1 | grep -q -- "--show-skipped"; then
  ARGS+=(--show-skipped)
fi

mkdir -p "$OUT_DIR"

echo "Running: infracost $CMD ${ARGS[*]}"
infracost "$CMD" "${ARGS[@]}"

# Infracost's own table (newer CLIs render it themselves; harmless if absent).
if infracost output --path "$JSON" --format table --no-color >/dev/null 2>&1; then
  infracost output --path "$JSON" --format table --no-color
fi

python3 scripts/infracost_summary.py "$JSON"
