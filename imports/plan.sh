#!/usr/bin/env bash
# =============================================================================
# imports/plan.sh <bootstrap-dev|bootstrap-prod|prod|monitoring|dev|all>
#
# READ-ONLY: stages the import blocks, runs `terraform plan` and saves the
# output to imports/plans/ so it can be committed for review. Nothing is
# applied. Run from the repo root.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/imports/plans"; mkdir -p "$OUT"
export AWS_REGION=eu-west-1 AWS_PAGER="" TF_IN_AUTOMATION=1

run() { # name dir profile extra-plan-args...
  local name=$1 dir=$2 profile=$3; shift 3
  local log="$OUT/$name.txt"
  echo "=== $name ($dir, $profile) -> imports/plans/$name.txt"
  (
    cd "$ROOT/$dir" || exit 1
    export AWS_PROFILE=$profile
    rm -f generated_legacy.tf
    echo "# $name  $(date -u +%FT%TZ)  terraform $(terraform version | head -1)"
    terraform init -input=false -no-color -reconfigure || exit 1
    terraform plan -input=false -no-color -lock=false -generate-config-out=generated_legacy.tf "$@"
    rc=$?
    echo; echo "# plan exit code: $rc"
    if [ -f generated_legacy.tf ]; then
      cp generated_legacy.tf "$OUT/$name.generated_legacy.tf"
      echo "# generated config copied to imports/plans/$name.generated_legacy.tf"
    fi
  ) > "$log" 2>&1
  grep -E "^Plan:|^Error|No changes|exit code" "$log" | sed 's/^/    /'
}

stage() { "$ROOT/imports/stage.sh" --unstage "$1" >/dev/null; "$ROOT/imports/stage.sh" "$1" >/dev/null; }

TARGET="${1:-all}"
case "$TARGET" in
  bootstrap-prod|bootstrap-dev|prod|monitoring|dev|all) ;;
  *) echo "usage: $0 bootstrap-dev|bootstrap-prod|prod|monitoring|dev|all" >&2; exit 2 ;;
esac
want() { [ "$TARGET" = all ] || [ "$TARGET" = "$1" ]; }

# Plain if-blocks (not `;;&`) so this runs on macOS's bash 3.2 too.
if want bootstrap-prod || want bootstrap-dev; then stage bootstrap; fi
if want bootstrap-prod; then run bootstrap-prod bootstrap agrovesto-prod -state=prod.tfstate -var-file=../imports/bootstrap/prod.tfvars; fi
if want bootstrap-dev;  then run bootstrap-dev  bootstrap agrovesto-dev  -state=dev.tfstate  -var-file=../imports/bootstrap/dev.tfvars; fi
if want prod;       then stage prod;       run prod prod agrovesto-prod; fi
if want monitoring; then stage monitoring; run monitoring monitoring agrovesto-prod; fi
if want dev;        then stage dev;        run dev dev agrovesto-dev; fi

echo
echo "Before committing imports/plans/, check for secrets (see RUNBOOK):"
echo "  grep -niE 'password|secret_string|token|private_key|AKIA' imports/plans/*"
