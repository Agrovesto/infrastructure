#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# The workflow may be an inactive root-level template or installed for Actions.
# Do not silently scan a stale template if both copies are present.
installed=.github/workflows/infrastructure.yml
template=infrastructure.yml
if [[ -f "$installed" && -f "$template" ]] && ! cmp -s "$installed" "$template"; then
  echo 'Workflow copies differ. Keep one canonical workflow or synchronize them before scanning.' >&2
  exit 1
fi
if [[ -f "$installed" ]]; then
  workflow=$installed
elif [[ -f "$template" ]]; then
  workflow=$template
else
  echo 'Missing infrastructure workflow: expected infrastructure.yml or .github/workflows/infrastructure.yml.' >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
# Checkov discovers workflows by path. Stage a COPY only in a disposable scan
# directory, never in the repository's active workflow folder. This does not
# enable or execute GitHub Actions.
mkdir -p "$tmp/workflow/.github/workflows"
cp "$workflow" "$tmp/workflow/.github/workflows/infrastructure.yml"

# Keep scanner failures AND require real results from all three frameworks.
status=0
checkov --config-file .checkov.yaml --framework terraform dockerfile --output json > "$tmp/source.json" || status=$?
checkov --config-file .checkov.yaml --directory "$tmp/workflow" --framework github_actions --output json > "$tmp/workflow.json" || status=$?
python3 scripts/ci/verify_checkov_report.py "$tmp/source.json" "$tmp/workflow.json"
exit "$status"
