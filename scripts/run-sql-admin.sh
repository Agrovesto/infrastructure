#!/usr/bin/env bash
# Requires an authorized operator's AWS session, AWS CLI, jq and initialized
# production backend. The normal infrastructure workflow NEVER executes SQL.
set -Eeuo pipefail
root=${1:-environments/prod}
sync_passwords=${2:-}
[[ -z "$sync_passwords" || "$sync_passwords" == --sync-passwords ]] || { echo 'Optional second argument must be --sync-passwords.' >&2; exit 1; }
[[ "$root" == environments/prod ]] || { echo 'This task is production-only.' >&2; exit 1; }
umask 077
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
expected=$(terraform -chdir="$root" output -raw account_id)
actual=$(aws sts get-caller-identity --query Account --output text)
[[ "$expected" == "$actual" ]] || { echo 'Wrong AWS account.' >&2; exit 1; }
terraform -chdir="$root" output -json sql_admin_run_task_input > "$tmp/input.json"
if [[ "$sync_passwords" == --sync-passwords ]]; then
  jq '.overrides = {containerOverrides: [{name: "sql-admin", command: ["provision", "--sync-passwords"]}]}'     "$tmp/input.json" > "$tmp/updated.json"
  mv "$tmp/updated.json" "$tmp/input.json"
fi
aws ecs run-task --cli-input-json "file://$tmp/input.json" > "$tmp/result.json"
jq -e '(.failures | length) == 0 and (.tasks | length) == 1' "$tmp/result.json" > /dev/null || { echo 'ECS rejected the admin task. Inspect the ECS console.' >&2; exit 1; }
cluster=$(jq -er .cluster "$tmp/input.json")
task=$(jq -er '.tasks[0].taskArn' "$tmp/result.json")
aws ecs wait tasks-stopped --cluster "$cluster" --tasks "$task"
aws ecs describe-tasks --cluster "$cluster" --tasks "$task" > "$tmp/status.json"
jq -e '(.failures | length) == 0 and (.tasks[0].containers | length) == 1 and .tasks[0].containers[0].exitCode == 0' "$tmp/status.json" > /dev/null || {
  echo 'SQL admin task failed; inspect the encrypted sql-admin log group. Services must remain disabled.' >&2
  exit 1
}
echo 'SQL database provisioning succeeded. Run application migrations before enabling services.'
