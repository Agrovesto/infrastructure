#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Run Terraform Native Test Suite & Coverage Checks
# Agrovesto Infrastructure
#
# Usage:
#   ./scripts/run_test_suite.sh dev     # Run dev test suite checks
#   ./scripts/run_test_suite.sh prod    # Run prod test suite checks
#   ./scripts/run_test_suite.sh all     # Run both test suites
# =============================================================================

TARGET="${1:-all}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"

run_module_tests() {
  local module="$1"
  local fail_under="${2:-60}"

  echo "================================================================="
  echo " Running Terraform Test Suite Checks for: $module"
  echo "================================================================="

  if [ ! -d "$module" ]; then
    echo "Error: Directory '$module' does not exist."
    exit 1
  fi

  cd "$REPO_ROOT/$module"
  echo "Initializing Terraform (providers only)..."
  terraform init -backend=false -input=false -no-color

  echo "Running terraform test suite..."
  set +e
  terraform test -no-color -json 2>test-stderr.log | tee test-results.json
  TEST_EXIT_CODE=$?
  set -e

  echo "Computing resource coverage & test suite summary..."
  cd "$REPO_ROOT"
  python3 scripts/tf_coverage.py "$module" \
    --test-json "$module/test-results.json" \
    --fail-under "$fail_under" \
    --json "$module/coverage.json" \
    --summary-md "$module/coverage.md"

  cat "$module/coverage.md"

  if [ $TEST_EXIT_CODE -ne 0 ]; then
    echo "::error::Test suite checks failed for $module"
    exit 1
  fi
}

case "$TARGET" in
  dev)
    run_module_tests "dev" 60
    ;;
  prod)
    run_module_tests "prod" 70
    ;;
  all)
    run_module_tests "dev" 60
    run_module_tests "prod" 70
    ;;
  *)
    echo "Usage: $0 [dev|prod|all]"
    exit 1
    ;;
esac

echo "================================================================="
echo " All test suite checks completed successfully!"
echo "================================================================="
