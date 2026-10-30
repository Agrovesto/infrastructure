#!/usr/bin/env bash
# Write a private JSON object to one production service's KV v2 appsettings path.
set -Eeuo pipefail
umask 077

prod_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail() { printf 'Prod Vault secret write refused: %s\n' "$1" >&2; exit 1; }
command -v terraform >/dev/null || fail "terraform is required to read vault_service_access"
command -v vault >/dev/null || fail "Vault CLI is required"
command -v python3 >/dev/null || fail "python3 is required"

[[ "$#" -eq 2 ]] || fail "usage: $0 <service> <private-json-file>"
service="$1"
secret_file="$2"
[[ -f "$secret_file" && ! -L "$secret_file" && -r "$secret_file" ]] || fail "JSON input must be a readable regular file, not a symlink"
if ! python3 - "$secret_file" <<'PY'
import os
import stat
import sys
mode = stat.S_IMODE(os.stat(sys.argv[1]).st_mode)
raise SystemExit(0 if mode & 0o077 == 0 else 1)
PY
then
  fail "JSON input must not be accessible by group/other; use mode 0600"
fi

access_json="$(terraform -chdir="$prod_dir" output -json vault_service_access)"
secret_path="$(python3 -c '
import json, sys
root = json.load(sys.stdin)
access = root.get("value", root)
service = access.get("services", {}).get(sys.argv[1]) if isinstance(access, dict) else None
if not service:
    raise SystemExit("unknown service or empty vault_service_access output")
print(service["secret_path"])
' "$service" <<<"$access_json")"
[[ "$secret_path" =~ ^kv/[a-z0-9-]+/prod/appsettings$ ]] || fail "invalid service Vault path from Terraform output"
secret_api_path="kv/data/${secret_path#kv/}"

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
command -v vault >/dev/null || fail "Vault CLI is required"

# The object is sent only on stdin; it is not placed in command arguments,
# Terraform state, shell history, or terminal output.
python3 - "$secret_file" <<'PY' | vault write -format=json "$secret_api_path" - >/dev/null
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as secret_file:
        values = json.load(secret_file)
except (OSError, json.JSONDecodeError) as exc:
    raise SystemExit(f"invalid service-secret JSON: {exc.__class__.__name__}")
if not isinstance(values, dict) or not values:
    raise SystemExit("service secrets must be a non-empty JSON object")
if not all(isinstance(key, str) and key for key in values):
    raise SystemExit("service secret keys must be non-empty strings")
print(json.dumps({"data": values}, separators=(",", ":")))
PY

unset VAULT_TOKEN
printf 'Wrote KV v2 data for %s at %s; values were not printed.\n' "$service" "$secret_path"
