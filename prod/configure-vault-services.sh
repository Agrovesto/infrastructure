#!/usr/bin/env bash
# Configure per-service KV v2 policies/AppRoles and store each AppRole credential
# bundle in its own AWS Secrets Manager secret. No KV payloads are fabricated.
set -Eeuo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
prod_dir="$script_dir"
secret_tmp=""
aws_error_tmp=""

cleanup() {
  [[ -z "$secret_tmp" ]] || rm -f "$secret_tmp"
  [[ -z "$aws_error_tmp" ]] || rm -f "$aws_error_tmp"
  unset VAULT_TOKEN
}
trap cleanup EXIT

fail() { printf 'Prod Vault service setup refused: %s\n' "$1" >&2; exit 1; }

command -v terraform >/dev/null || fail "terraform is required to read the applied vault_service_access output"
command -v vault >/dev/null || fail "Vault CLI is required"
command -v aws >/dev/null || fail "AWS CLI is required"
command -v python3 >/dev/null || fail "python3 is required"

access_json="$(terraform -chdir="$prod_dir" output -json vault_service_access)"
service_rows="$(python3 -c '
import json, sys
root = json.load(sys.stdin)
access = root.get("value", root)
if not isinstance(access, dict) or not access.get("services"):
    raise SystemExit("vault_service_access is empty; apply prod with enable_vault=true first")
cluster = access["cluster"]
vault_mode = "true" if access.get("vault_secrets_enabled") is True else "false"
for service, item in sorted(access["services"].items()):
    fields = [service, item["secret_path"], item["policy"], item["approle"],
              item["credentials_secret_arn"], cluster, item["ecs_service"], vault_mode]
    print("\t".join(fields))
' <<<"$access_json")"
[[ -n "$service_rows" ]] || fail "no application ECS services were found in Terraform output"

is_known_service() {
  local candidate
  while IFS=$'\t' read -r candidate _; do
    [[ "$candidate" == "$1" ]] && return 0
  done <<<"$service_rows"
  return 1
}

should_rotate() {
  local selected
  [[ "$rotate_all" == true ]] && return 0
  for selected in "${rotate_services[@]}"; do
    [[ "$selected" == "$1" ]] && return 0
  done
  return 1
}

rotate_all=false
declare -a rotate_services=()
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --rotate)
      [[ "$#" -ge 2 ]] || fail "--rotate requires a service name"
      is_known_service "$2" || fail "unknown service '$2'"
      rotate_services+=("$2")
      shift 2
      ;;
    --rotate-all)
      rotate_all=true
      shift
      ;;
    -h|--help)
      printf 'Usage: %s [--rotate <service>] [--rotate-all]\n' "$0"
      exit 0
      ;;
    *) fail "unknown option '$1' (use --help)" ;;
  esac
done

if [[ -z "${VAULT_ADDR:-}" ]]; then
  VAULT_ADDR="$(terraform -chdir="$prod_dir" output -raw vault_url)"
fi
[[ "$VAULT_ADDR" == https://* ]] || fail "set VAULT_ADDR to the production Vault HTTPS URL"
export VAULT_ADDR

if [[ -z "${VAULT_TOKEN:-}" ]]; then
  [[ -r /dev/tty ]] || fail "set VAULT_TOKEN through a secure administrative session"
  read -r -s -p "Vault administrator token: " VAULT_TOKEN </dev/tty
  printf '\n' >/dev/tty
fi
[[ -n "$VAULT_TOKEN" ]] || fail "an administrator token is required"
export VAULT_TOKEN

status_json="$(vault status -format=json 2>/dev/null || true)"
if ! python3 -c '
import json, sys
try:
    status = json.loads(sys.stdin.read())
except json.JSONDecodeError:
    raise SystemExit(1)
raise SystemExit(0 if status.get("initialized") and not status.get("sealed") else 1)
' <<<"$status_json"; then
  fail "Vault must be initialized and unsealed before configuring service access"
fi

mounts_json="$(vault secrets list -format=json)"
mount_state="$(python3 -c '
import json, sys
mounts = json.load(sys.stdin)
mount = mounts.get("kv/")
if mount is None:
    print("missing")
elif mount.get("type") == "kv" and str(mount.get("options", {}).get("version", "")) == "2":
    print("kv-v2")
else:
    print("incompatible")
' <<<"$mounts_json")"
case "$mount_state" in
  missing) vault secrets enable -path=kv kv-v2 >/dev/null ;;
  kv-v2) ;;
  *) fail "kv/ exists but is not KV version 2" ;;
esac

auth_json="$(vault auth list -format=json)"
auth_state="$(python3 -c '
import json, sys
methods = json.load(sys.stdin)
method = methods.get("approle/")
if method is None:
    print("missing")
elif method.get("type") == "approle":
    print("approle")
else:
    print("incompatible")
' <<<"$auth_json")"
case "$auth_state" in
  missing) vault auth enable approle >/dev/null ;;
  approle) ;;
  *) fail "auth/approle exists but is not the AppRole auth method" ;;
esac

read_secret_field() {
  local key="$1"
  python3 -c 'import json,sys; d=json.load(sys.stdin); d=d.get("data", d); v=d.get(sys.argv[1], ""); print(v if isinstance(v, str) else "")' "$key"
}

while IFS=$'\t' read -r service secret_path policy role secret_arn cluster ecs_service vault_mode <&3; do
  [[ -n "$service" ]] || continue
  [[ "$secret_path" == kv/* ]] || fail "invalid Vault path in Terraform output for $service"
  [[ "$vault_mode" == true || "$vault_mode" == false ]] || fail "invalid vault_secrets_enabled value in Terraform output"
  path_suffix="${secret_path#kv/}"
  api_path="kv/data/$path_suffix"

  vault policy write "$policy" - <<POLICY >/dev/null
# KV v2 data is read-only for this service. Token lifecycle access is self-only.
path "$api_path" {
  capabilities = ["read"]
}
path "$api_path/*" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/revoke-self" {
  capabilities = ["update"]
}
POLICY

  vault write "auth/approle/role/$role" \
    "token_policies=$policy" \
    token_no_default_policy=true \
    token_ttl=1h \
    token_max_ttl=24h \
    secret_id_ttl=8760h \
    secret_id_num_uses=0 >/dev/null

  role_id="$(vault read -field=role_id "auth/approle/role/$role/role-id")"
  [[ "$role_id" =~ ^[A-Za-z0-9._-]+$ ]] || fail "Vault returned an invalid RoleID for $service"

  aws_error_tmp="$(mktemp)"
  if existing_json="$(aws secretsmanager get-secret-value \
    --secret-id "$secret_arn" --query SecretString --output text 2>"$aws_error_tmp")"; then
    :
  elif grep -Fq 'ResourceNotFoundException' "$aws_error_tmp" && \
    grep -Fqi 'specified secret value' "$aws_error_tmp"; then
    # Terraform creates the empty secret container before its first version.
    existing_json=""
  else
    rm -f "$aws_error_tmp"
    aws_error_tmp=""
    fail "could not retrieve the existing credential bundle for $service; check Secrets Manager access and state"
  fi
  rm -f "$aws_error_tmp"
  aws_error_tmp=""

  existing_role_id=""
  existing_secret_id=""
  old_accessor=""
  if [[ -n "$existing_json" && "$existing_json" != None ]]; then
    existing_role_id="$(printf '%s' "$existing_json" | read_secret_field role_id || true)"
    existing_secret_id="$(printf '%s' "$existing_json" | read_secret_field secret_id || true)"
    old_accessor="$(printf '%s' "$existing_json" | read_secret_field secret_id_accessor || true)"
  fi

  if [[ -n "$existing_secret_id" && -z "$old_accessor" ]]; then
    if [[ "$existing_role_id" != "$role_id" ]] || should_rotate "$service"; then
      fail "$service has an old SecretID without a saved accessor; revoke it manually before rotating"
    fi
    printf 'WARNING: %s has no saved SecretID accessor; future rotation will need manual revocation.\n' "$service" >&2
  fi

  secret_id=""
  new_accessor=""
  generated_new=false
  if [[ -n "$existing_role_id" && -n "$existing_secret_id" && "$existing_role_id" == "$role_id" ]] && ! should_rotate "$service"; then
    secret_id="$existing_secret_id"
    new_accessor="$old_accessor"
  else
    secret_json="$(vault write -format=json -f "auth/approle/role/$role/secret-id")"
    secret_id="$(printf '%s' "$secret_json" | read_secret_field secret_id)"
    new_accessor="$(printf '%s' "$secret_json" | read_secret_field secret_id_accessor)"
    unset secret_json
    generated_new=true
  fi
  [[ "$secret_id" =~ ^[A-Za-z0-9._-]+$ ]] || fail "Vault returned an invalid SecretID for $service"

  if [[ "$generated_new" == true ]]; then
    secret_tmp="$(mktemp)"
    chmod 0600 "$secret_tmp"
    printf '{"role_id":"%s","secret_id":"%s","secret_id_accessor":"%s"}\n' \
      "$role_id" "$secret_id" "$new_accessor" >"$secret_tmp"
    if ! aws secretsmanager put-secret-value \
      --secret-id "$secret_arn" --secret-string "file://$secret_tmp" >/dev/null; then
      if [[ -n "$new_accessor" ]]; then
        printf '{"secret_id_accessor":"%s"}' "$new_accessor" | \
          vault write -format=json "auth/approle/role/$role/secret-id-accessor/destroy" - >/dev/null 2>&1 || true
      fi
      fail "could not store the AppRole credential bundle for $service in Secrets Manager"
    fi
    rm -f "$secret_tmp"
    secret_tmp=""
  fi

  # For an explicit rotation, roll this ECS service onto the new SecretID and
  # wait until it is stable before revoking the previous SecretID.
  if should_rotate "$service" || \
    { [[ "$generated_new" == true && "$vault_mode" == true ]]; }; then
    aws ecs update-service --cluster "$cluster" --service "$ecs_service" \
      --force-new-deployment >/dev/null
    aws ecs wait services-stable --cluster "$cluster" --services "$ecs_service"
  fi

  if [[ -n "$old_accessor" && -n "$new_accessor" && "$old_accessor" != "$new_accessor" ]]; then
    if ! printf '{"secret_id_accessor":"%s"}' "$old_accessor" | \
      vault write -format=json "auth/approle/role/$role/secret-id-accessor/destroy" - >/dev/null; then
      printf 'WARNING: old SecretID for %s could not be revoked; review Vault audit output.\n' "$service" >&2
    fi
  fi

  printf 'Configured %s: path=%s, policy=%s, AppRole=%s, Secrets Manager ARN=%s\n' \
    "$service" "$secret_path" "$policy" "$role" "$secret_arn"
done 3<<<"$service_rows"

unset VAULT_TOKEN
printf '\nAppRole credentials are stored in per-service Secrets Manager secrets; KV appsettings payloads remain operator-provided.\n'
