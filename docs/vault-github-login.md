# Dev Vault HTTPS and GitHub login

The checked-in dev settings enable `vault.subdomain = "dev-vault"` and
`vault.oidc_enabled = true`. These configure **https://dev-vault.nomaos.com** through
Caddy → nginx → Vault, with Dex at `/dex`. This is configuration, not evidence of a
successful deployment. nginx rejects public initialization writes (`/v1/sys/init`);
initialize only through the private operator path. Initialize fresh Vault using the [fresh setup runbook](vault-fresh-setup.md)
first; do not use the historical Shamir migration procedure for a new installation.

## Required operator setup before merging/applying

1. Compare `terraform -chdir=dev output -raw ec2_public_ip` with public DNS for
   `dev-vault.nomaos.com`. DNS resolved to `108.129.68.122` during preparation, but
   it must match the current dev EIP. The prod account owns DNS; this PR does not
   overwrite/adopt the manually managed record. Permit inbound 80/443 for Caddy
   ACME/HTTPS. Never expose Vault's HTTP port 8200 publicly.
2. Register a **dedicated GitHub OAuth App** (not the Grafana app):
   - Homepage: `https://dev-vault.nomaos.com`
   - Authorization callback: `https://dev-vault.nomaos.com/dex/callback`
   - Allow the app under organization OAuth restrictions, if applicable.
3. Under this repository's **Settings → Secrets and variables → Actions**, store
   these **repository secrets**, not plaintext variables:
   - `DEV_VAULT_GITHUB_CLIENT_ID`: the OAuth App client ID.
   - `DEV_VAULT_GITHUB_CLIENT_SECRET`: its client secret.
   - `DEV_VAULT_OIDC_CLIENT_SECRET`: an independent random secret generated locally
     (for example `openssl rand -hex 32`). Preserve it across future deployments.
   Never paste values in chat or commit them. The dev caller already forwards these
   to the reusable workflow; plan/apply steps pass them to Terraform, which stores
   them in encrypted SSM SecureStrings. Terraform state and saved plans also contain
   them and must be restricted. Secret metadata could not be verified from this
   session because GitHub returned HTTP 403.
4. Confirm a verified backup and KMS restart readiness for initialized Vault, or
   confirm this is the approved empty fresh setup. Then set repository **variable**
   `DEV_VAULT_OIDC_RESTART_ACK` to `true`. It defaults to false in CI: the plan fails
   closed without operator approval. Reassess this standing acknowledgement before
   later restart-causing changes; resetting it to false blocks subsequent plans.
5. Review PR #32 and a complete Terraform plan. No EC2 replacement or destruction
   of existing KMS/storage is expected. Apply only after review. SSM prepares mounted
   storage, retrieves OAuth credentials into root-only `.env`, then starts Compose.

Local runs need the corresponding environment variables from your secure secret
manager: `TF_VAR_vault_github_client_id`, `TF_VAR_vault_github_client_secret`,
`TF_VAR_vault_oidc_client_secret`, plus `TF_VAR_vault_oidc_restart_ack=true` after
approval. Do not put secret assignments in shell history. GitHub Actions secrets
are not automatically available to a local Terraform command.

## Verify HTTPS before configuring auth

From a client browser/network:

```bash
curl --fail --show-error https://dev-vault.nomaos.com/dex/.well-known/openid-configuration
```

Expect issuer `https://dev-vault.nomaos.com/dex`, with a valid certificate (do not
use `curl -k`). On the host, inspect Caddy/Dex logs and confirm Vault is initialized
and unsealed. Initializing an empty Vault remains a private manual operation, never
an SSM Run Command or Terraform provisioner.

## One-time Vault OIDC bootstrap AFTER initialization

Use a private administrative channel that is approved for privileged operations.
Do not paste an admin token in chat, CI, Terraform, or shell command arguments. The
script requires Docker access and reads the active Dex client secret through a
captured Docker-inspect pipe. It does not read or loosen permissions on the
root-only Compose `.env`. Docker membership is privileged host access.

In an authorized shell with tracing disabled:

```bash
set +x
read -rsp 'Temporary Vault admin token: ' VAULT_TOKEN; printf '\n'
export VAULT_TOKEN
bash /opt/agrovesto/scripts/configure-vault-oidc.sh
unset VAULT_TOKEN
```

The script refuses sealed/uninitialized Vault, configures OIDC and binds the
`Agrovesto:infrastructure` GitHub team to `dev-vault-operator`. Docker inherits the
token via environment rather than a token-bearing command-line argument. Privileged
host administrators can still inspect process environments: secure this host.

The Vault role's callback is
`https://dev-vault.nomaos.com/ui/vault/auth/oidc/oidc/callback` (distinct from the
GitHub OAuth App's Dex callback). The role also supports the loopback CLI callback.

Open **https://dev-vault.nomaos.com/ui/vault/auth?with=oidc** and test an authorized
team member. Verify unauthorized users cannot obtain the operator policy. The
operator policy is scoped to `kv/data/*` and `kv/metadata/*`; it does not grant root
or general auth/system administration. On a fresh Vault, an administrator must
separately enable the KV v2 engine at `kv/` if desired; bootstrap does not overwrite
or create application secrets. Configure application policies/auth separately.

Only after testing login and break-glass recovery should you revoke the initial
root token. Keep recovery shares and the KMS key secure. The API/UI remains a public
TLS endpoint requiring Vault authentication; GitHub login is an auth method, not a
blanket reverse-proxy gate on every Vault API route.
