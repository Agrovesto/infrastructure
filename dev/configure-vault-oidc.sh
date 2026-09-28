#!/usr/bin/env bash
# Run on the dev host AFTER persistent Vault has been initialized and the
# initialization/unsealing verified. Requires a temporary VAULT_TOKEN (operator-supplied);
# never put an admin token in Terraform, S3, .env, shell history or CI.
set -euo pipefail
: "$${VAULT_TOKEN:?Set VAULT_TOKEN in the current shell for one-time bootstrap}"
# Docker access is already privileged. Read ONLY the active Dex client secret
# into a captured pipe, without opening or relaxing the host's root-only .env.
# No shell/printenv is required inside the Dex image. Never run with tracing.
set +x
VAULT_OIDC_CLIENT_SECRET=$(docker inspect agrovesto-dex | python3 -c '
import json, sys
container = json.load(sys.stdin)[0]
if not container.get("State", {}).get("Running"):
    raise SystemExit("Dex must be running before OIDC bootstrap")
for entry in container["Config"].get("Env", []):
    name, _, value = entry.partition("=")
    if name == "VAULT_OIDC_CLIENT_SECRET" and value:
        sys.stdout.write(value)
        break
else:
    raise SystemExit("Dex OIDC client secret is missing")
')
: "$${VAULT_OIDC_CLIENT_SECRET:?missing Dex client secret}"
export VAULT_OIDC_CLIENT_SECRET VAULT_TOKEN

vault() { docker exec -i -e VAULT_TOKEN agrovesto-vault vault "$@"; }

# Refuse bootstrap until initialization and KMS unsealing are complete.
vault status -format=json | python3 -c 'import json,sys; s=json.load(sys.stdin); sys.exit(not(s["initialized"] and not s["sealed"]))'
# Do not mistake connectivity/authorization errors for a missing auth mount.
auth_mounts=$(vault auth list -format=json)
if ! printf '%s' "$auth_mounts" | python3 -c 'import sys,json; sys.exit("oidc/" not in json.load(sys.stdin))'; then
  vault auth enable oidc
fi
vault auth tune -listing-visibility=unauth oidc

# JSON via stdin: never place the Dex client secret on the command line.
python3 - <<'PY' | vault write auth/oidc/config -
import json, os
print(json.dumps({
    "oidc_discovery_url": "https://${vault_fqdn}/dex",
    "oidc_client_id": "vault",
    "oidc_client_secret": os.environ["VAULT_OIDC_CLIENT_SECRET"],
    "default_role": "github",
}))
PY

python3 - <<'PY' | vault write auth/oidc/role/github -
import json
print(json.dumps({
    "role_type": "oidc",
    "bound_audiences": ["vault"],
    "allowed_redirect_uris": [
        "https://${vault_fqdn}/ui/vault/auth/oidc/oidc/callback",
        "http://localhost:8250/oidc/callback",
    ],
    "user_claim": "sub",
    "groups_claim": "groups",
    "oidc_scopes": ["openid", "profile", "email", "groups"],
    "token_policies": ["default"],
    "token_ttl": "1h",
    "token_max_ttl": "4h",
}))
PY

vault policy write dev-vault-operator - </opt/agrovesto/vault/operator.hcl
accessor=$(vault auth list -format=json | python3 -c 'import sys,json; print(json.load(sys.stdin)["oidc/"]["accessor"])')
# Upsert by name: Vault creates a missing group or updates the existing one.
# Do not suppress read/permission failures or parse an expected empty 404 body.
vault write identity/group/name/dev-vault-github-operators type=external policies=dev-vault-operator >/dev/null
group_json=$(vault read -format=json identity/group/name/dev-vault-github-operators)
group_id=$(printf '%s' "$group_json" | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["id"])')
alias_id=$(printf '%s' "$group_json" | python3 -c 'import sys,json; print((json.load(sys.stdin)["data"].get("alias") or {}).get("id", ""))')
if [ -n "$alias_id" ]; then
  vault write identity/group-alias/id/"$alias_id" name="${github_org}:${github_team}" mount_accessor="$accessor" canonical_id="$group_id" >/dev/null
else
  vault write identity/group-alias name="${github_org}:${github_team}" mount_accessor="$accessor" canonical_id="$group_id" >/dev/null
fi
printf '%s\n' 'OIDC configured. Test a team member login and verify policy dev-vault-operator before revoking the bootstrap root token.'
