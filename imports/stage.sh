#!/usr/bin/env bash
# =============================================================================
# imports/stage.sh <stack>            copy import files into the stack
# imports/stage.sh --unstage <stack>  remove them again (after the apply)
#
# stack: bootstrap | dev | prod | monitoring
#
# Import blocks live under imports/ and are copied in only for the import
# window. That keeps CI (`terraform test` with mock providers) and normal
# applies free of one-shot import blocks, and makes "done" easy to check.
# Staged copies are prefixed zz_import_ and git-ignored.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"

if [ "${1:-}" = "--unstage" ]; then
  S="${2:?stack}"; rm -fv "$ROOT/$S"/zz_import_*.tf; exit 0
fi
S="${1:?usage: stage.sh [--unstage] bootstrap|dev|prod|monitoring}"
[ -d "$HERE/$S" ] || { echo "no imports/$S" >&2; exit 2; }
for f in "$HERE/$S"/*.tf; do
  cp -v "$f" "$ROOT/$S/zz_import_$(basename "$f")"
done
echo
echo "Next: cd $S && terraform init && terraform plan -generate-config-out=generated_legacy.tf -out=tfplan"
