# Dev API secrets in Vault and per-service env files

This runbook configures the **Dev EC2 API services** (`var.apis` in
`dev/terraform.auto.tfvars`) to authenticate to the existing dev Vault. Prod's
five ECS APIs use the separate AppRole and Secrets Manager design documented in
[the Prod runbook](prod-vault-service-secrets.md); Prod does not use EC2 host env
files.

The list is generated from Terraform, so a newly added API gets its own path,
read policy, AppRole and env-file location on the next apply/bootstrap. The Dev
Terraform environment remains named `dev`; its Vault path namespace is `staging`
to match the application configuration contract.

## Layout and access boundaries

For the current Dev API map, the generated resources are:

| API | KV v2 path in Vault UI | Policy | AppRole | Host env file |
|---|---|---|---|---|
| `agx` | `kv/agx/staging/appsettings` | `dev-agx-read` | `dev-agx` | `/data/vault/services/agx.env` |
| `nomaos` | `kv/nomaos/staging/appsettings` | `dev-nomaos-read` | `dev-nomaos` | `/data/vault/services/nomaos.env` |
| `wallet` | `kv/wallet/staging/appsettings` | `dev-wallet-read` | `dev-wallet` | `/data/vault/services/wallet.env` |
| `onboarding` | `kv/onboarding/staging/appsettings` | `dev-onboarding-read` | `dev-onboarding` | `/data/vault/services/onboarding.env` |
| `input` | `kv/input/staging/appsettings` | `dev-input-read` | `dev-input` | `/data/vault/services/input.env` |
| `moneval` | `kv/moneval/staging/appsettings` | `dev-moneval-read` | `dev-moneval` | `/data/vault/services/moneval.env` |
| `serviceprovider` | `kv/serviceprovider/staging/appsettings` | `dev-serviceprovider-read` | `dev-serviceprovider` | `/data/vault/services/serviceprovider.env` |

The policies use the KV v2 API paths
`kv/data/<service>/staging/appsettings` and its descendants, with **read only**
capability. They grant no KV list or write access, no access to another service's
data, and no general `sys/*` or `auth/*` access. The only auth paths are `auth/token/renew-self`,
`auth/token/lookup-self` and `auth/token/revoke-self`, so an app can manage only
its own token while `token_no_default_policy` stays enabled. The human Vault
operator policy remains separate. If an application needs KV metadata or list
operations, review and add only the specific capability it needs.

Each generated `.env` contains `VAULT_ADDR`, `VAULT_KV_MOUNT`,
`VAULT_SECRET_PATH`, `VAULT_ROLE_ID` and `VAULT_SECRET_ID`. For `nomaos`,
`VAULT_SECRET_PATH` is the full UI/config path `kv/nomaos/staging/appsettings`;
KV v2 API access uses `kv/data/nomaos/staging/appsettings`. The AppRole token has
a 1-hour TTL and a 24-hour maximum TTL. Its SecretID is valid for one year to
support host restarts and blue/green slots, and can be explicitly rotated. The
service env file is owned by `root:docker` with mode `0640`; the directory is
`root:docker` mode `0750`. It is stored on the dedicated encrypted Vault EBS
volume, so it survives EC2 replacement with that volume. EBS snapshots include
these AppRole credentials too—restrict snapshot and volume access accordingly.

Compose-managed APIs and Vault already share the Compose network. The
independently deployed blue/green slots use the external `nomaos_edge` network;
a small post-Compose hook attaches the existing Vault container there with the
`vault` DNS alias, so policy/config refreshes do not recreate Vault just to add a
network. Services use `http://vault:8200` on the private Docker network; port
8200 remains loopback-bound on the EC2 host and is not opened in the security
group.
Do not publish the service env files to the host-config S3 bucket, Git,
Terraform state, CI output or application logs. Docker access is root-equivalent,
and a process environment is visible to host administrators.

## Provision AppRoles and env files

1. Apply the Dev infrastructure changes and wait for the fresh Vault setup to
   finish. Vault must already be **initialized and unsealed**. For the dedicated
   EBS and KMS prerequisites, follow [Fresh dev Vault setup](vault-fresh-setup.md).
2. Ensure the host has synced the host-config bucket (a Terraform apply runs the
   SSM refresh association). The scripts and non-secret policy HCL files should
   exist under `/opt/agrovesto/scripts` and `/opt/agrovesto/vault/service-policies`.
3. Open an approved private administrative session on the host. Run the setup
   from a root shell:

   ```bash
   sudo -i
   bash /opt/agrovesto/scripts/configure-vault-services.sh
   ```

   The script prompts without echo for a Vault administrator token if
   `VAULT_TOKEN` is not already set. **Do not use SSM Run Command or a session
   with input/output logging enabled for a root token.** Do not place the token
   in a command argument, shell history, `.env` file or Terraform variable.
4. The script verifies `/data/vault` is mounted and Vault is initialized and
   unsealed, enables KV v2 at `kv/` and AppRole at `auth/approle/` only if each is
   absent, writes one read-only policy and role per API, then writes the private
   env files. It is safe to rerun: it updates policy/role settings but preserves
   an existing valid SecretID unless rotation is requested. SecretID values are
   never printed. No secret payload is fabricated or copied from the SQL Server
   `sa` password.

The script provisions the **path and access policy**, not application data. KV
paths become visible when a secret is written. The real secret keys depend on
each API's configuration; common examples are `DB_USER`, `DB_PASSWORD`,
`DB_NAME`, or service-specific API credentials. Use individual database logins
and passwords where possible—do not share SQL Server `sa` credentials across
services. If an app also receives `DB_CONNECTION_STRING`, keep credentials out
of that value and construct it from the KV data, or store the complete
connection string only in Vault. The API must support AppRole login and KV v2
reads; infrastructure only supplies its own Vault connection details.

## Write a service's secret payload

Prepare a non-empty JSON object using your approved secret-handling process and
store it temporarily in a root-only file (for example under `/run`, which is
memory-backed). The JSON values are sent to Vault through stdin; they are not
passed as command-line arguments or printed by the helper. Example **shape only**:

```json
{
  "DB_USER": "<service-specific database login>",
  "DB_PASSWORD": "<secret value>",
  "DB_NAME": "wallet"
}
```

Restrict the file before writing it:

```bash
chmod 0600 /run/wallet-secrets.json
bash /opt/agrovesto/scripts/write-vault-service-secret.sh wallet /run/wallet-secrets.json
```

The helper rejects files readable by group/other, rejects unknown service names,
wraps the object for KV v2, writes to
`kv/data/<service>/staging/appsettings`, and suppresses the Vault response body. Remove the temporary JSON file using the approved local
handling process after a successful write. Never type real secret values in the
command itself or commit the JSON file.

## Application rollout and verification

- Compose-managed API services load `/data/vault/services/<service>.env` using
  the optional `env_file` entry in the rendered Compose file. After provisioning
  or rotating credentials, recreate the relevant Compose API container so it
  receives the current env file.
- Blue/green slots are launched by the app repository, not this Compose project.
  Its deploy wrapper must load the matching host env file before launching a
  slot; the reference implementation is
  [`docs/examples/deploy.sh`](examples/deploy.sh). Redeploy each API after its
  KV payload and env file are ready.
- The app should authenticate using `VAULT_ROLE_ID` and `VAULT_SECRET_ID`, then
  read the full `VAULT_SECRET_PATH` (for example
  `kv/nomaos/staging/appsettings`) using its KV v2 client. The Compose services
  also receive `Vault__SecretPath`, the .NET environment-variable mapping for
  the JSON key `Vault:SecretPath`. The blue/green app compose file must pass this
  variable through from the deployment wrapper. If the application reads Vault
  dynamically after startup, it must renew or reauthenticate before its 24-hour
  maximum token TTL. Do not log the env values, Vault response, token, connection
  strings or secret data.
- Review file names and modes without printing contents:

  ```bash
  find /data/vault/services -maxdepth 1 -type f -name '*.env' -printf '%m %u:%g %f\n'
  ```

The infrastructure bootstrap does not deploy app code or prove that an app
actually reads its KV path. Validate one service end-to-end with a non-production
secret before rolling the remaining services.

## SecretID rotation

Rotate one API when its SecretID is exposed or during planned credential rotation:

```bash
bash /opt/agrovesto/scripts/configure-vault-services.sh --rotate wallet
```

The script creates the replacement, atomically updates that service's env file,
then revokes the previous SecretID using its accessor. Already-issued Vault tokens
remain valid until revoked or expired, so redeploy the app and account for the
24-hour maximum token TTL. `--rotate-all` rotates all API SecretIDs. Do not copy
SecretIDs between API files; each policy is intentionally isolated.

## Scope and production

This runbook covers the Dev EC2 APIs and their host env files. It does not create
SQL logins, guess app-specific secret fields or write passwords without an
operator-provided payload. Prod Fargate uses a separate per-service AppRole and
AWS Secrets Manager contract; see [Prod ECS Vault service access](prod-vault-service-secrets.md).
