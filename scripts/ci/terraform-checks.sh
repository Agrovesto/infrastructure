#!/usr/bin/env bash
set -Eeuo pipefail
root=${1:?Usage: terraform-checks.sh ROOT}
case "$root" in
  bootstrap/dev|bootstrap/prod|environments/dev|environments/prod) ;;
  *) echo 'Unsupported Terraform root' >&2; exit 1 ;;
esac
# No AWS credential step, no backend connection, no live PR plan.
export TF_IN_AUTOMATION=true TF_INPUT=false AWS_EC2_METADATA_DISABLED=true
terraform -chdir="$root" init -backend=false -lockfile=readonly
terraform -chdir="$root" validate -no-color
terraform -chdir="$root" test -no-color
