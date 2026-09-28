#!/usr/bin/env bash
# Run on the dev host AFTER persistent Vault has been initialized and the
# initialization/unsealing verified. Requires a temporary VAULT_TOKEN (operator-supplied);
# never put an admin token in Terraform, S3, .env, shell history or CI.
set -euo pipefail
: "$${VAULT_TOKEN:?Set VAULT_TOKEN in the current shell for one-time bootstrap}"
cd /opt/agrovesto/compose
# Read ONLY the OIDC client secret from the root-only Compose .env without
# evaluating it as shell code (other application passwords can contain metacharacters).
VAULT_OIDC_CLIENT_SECRET=$(python3 - <<'PYCODE'
from pathlib import Path
for line in Path(".env").read_text().splitlines():
    if line.startswith("VAULT_OIDC_CLIENT_SECRET="):
        print(line.partition("=")[2])
        break
PYCODE
)
: "$${VAULT_OIDC_CLIENT_SECRET:?missing Dex client secret in .env}"
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
# Create the external group once; subsequent runs update its policy, not its ID.
group_id=$(vault read -format=json identity/group/name/dev-vault-github-operators 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["id"])') || true
if [ -z "$group_id" ]; then
  group_id=$(vault write -format=json identity/group name=dev-vault-github-operators type=external policies=dev-vault-operator | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["id"])')
else
  vault write identity/group/id/"$group_id" name=dev-vault-github-operators type=external policies=dev-vault-operator >/dev/null
fi
vault write identity/group-alias name="${github_org}:${github_team}" mount_accessor="$accessor" canonical_id="$group_id" >/dev/null
printf '%s\n' 'OIDC configured. Test a team member login and verify policy dev-vault-operator before revoking the bootstrap root token.'
