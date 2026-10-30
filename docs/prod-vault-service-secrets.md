# Production ECS services: Vault paths and per-service AppRoles

This runbook wires the five production API services to service-scoped KV v2
paths. Terraform exposes the path/access metadata and creates empty Secrets
Manager containers for AppRole credentials; an operator initializes Vault,
configures roles, and writes the real application payloads. No secret values or
application-specific appsettings schema are invented by Terraform.

## ECS names and deployment controller

The current production defaults resolve to:

- **ECS cluster:** `agrovesto-prod` (`terraform output ecs_cluster_name`).
- **Application ECS services:** `wallet`, `onboarding`, `input`, `moneval`,
  `serviceprovider`.
- **Vault ECS service:** `vault` when `enable_vault = true` (true by default).
- `terraform output ecs_service_names` returns the service-name map; it includes
  `vault` when Vault is enabled.

The application services and Vault explicitly use
`deployment_controller.type = "ECS"`, also reported by
`terraform output ecs_deployment_controller`. This is the ECS rolling
deployment controller with the configured deployment circuit breaker and
rollback—not the CodeDeploy blue/green controller.

## Per-service path convention

Paths follow the requested `kv/<service>/<environment>/appsettings` shape. The
Dev path namespace is `staging`; this Prod stack uses `prod`:

| ECS service | Vault UI / `Vault:SecretPath` | KV v2 API path | AppRole | Secrets Manager credential name |
|---|---|---|---|---|
| `wallet` | `kv/wallet/prod/appsettings` | `kv/data/wallet/prod/appsettings` | `prod-wallet` | `agrovesto-prod/wallet/vault-approle` |
| `onboarding` | `kv/onboarding/prod/appsettings` | `kv/data/onboarding/prod/appsettings` | `prod-onboarding` | `agrovesto-prod/onboarding/vault-approle` |
| `input` | `kv/input/prod/appsettings` | `kv/data/input/prod/appsettings` | `prod-input` | `agrovesto-prod/input/vault-approle` |
| `moneval` | `kv/moneval/prod/appsettings` | `kv/data/moneval/prod/appsettings` | `prod-moneval` | `agrovesto-prod/moneval/vault-approle` |
| `serviceprovider` | `kv/serviceprovider/prod/appsettings` | `kv/data/serviceprovider/prod/appsettings` | `prod-serviceprovider` | `agrovesto-prod/serviceprovider/vault-approle` |

There is currently **no `nomaos` ECS API service in Prod**. The supplied
`kv/nomaos/staging/appsettings` example corresponds to the Dev `nomaos` API. A
Prod `kv/nomaos/prod/appsettings` path will be generated only if `nomaos` is
added to `prod/var.services`.

Each policy grants `read` only on that service's KV path and descendants. It
also grants only self-token renew/lookup/revoke capabilities. `token_no_default_policy`
remains enabled; no service can list or write KV data or read another service's
path. AppRole tokens have a 1-hour TTL and a 24-hour maximum; SecretIDs are
valid for one year (`8760h`), so schedule rotation before expiry.

When `vault_secrets_enabled = true`, ECS sets `Vault__SecretPath` to the full UI
path. For .NET, `Vault__SecretPath` maps to the JSON configuration key
`{"Vault":{"SecretPath":"..."}}`. The tasks also receive `VAULT_SECRET_PATH`,
`VAULT_KV_MOUNT=kv`, `VAULT_AUTH_METHOD=approle`, and `VAULT_ADDR`. ECS injects
that service's `VAULT_ROLE_ID` and `VAULT_SECRET_ID` from its own Secrets Manager
secret. Terraform stores only the secret container metadata/ARN, never its
SecretString value. Unlike Dev EC2, Prod Fargate does not use host-side plaintext
`.env` files: each task definition carries that service's non-secret settings
and references its own Secrets Manager credential bundle for secret values.

## Provision access and credentials

1. Apply Prod with `enable_vault = true` and
   `vault_secrets_enabled = false`. This creates the Vault ECS service and an
   empty Secrets Manager credential secret for each API. The bootstrap DB
   credentials remain sourced from the RDS-managed Secrets Manager secret.
2. Initialize/unseal Vault and securely save the root/break-glass token. Do not
   put it in Terraform variables, command arguments, CI logs, or shell history.
3. From a private operator workstation with Terraform state access, Vault CLI,
   AWS CLI and Python 3, and an AWS identity permitted to get/put these Secrets
   Manager values (plus `ecs:UpdateService` and `ecs:DescribeServices` for
   rotation), run:

   ```bash
   cd prod
   bash configure-vault-services.sh
   ```

   The script reads the non-secret `vault_service_access` output, prompts for
   the Vault token without echo if needed, checks that Vault is initialized and
   unsealed, enables KV v2/AppRole only if absent, then writes one read policy
   and AppRole per ECS API. It stores the RoleID, SecretID and SecretID accessor
   JSON in that API's Secrets Manager secret. It does not print those values.
   The same command is safe to rerun and preserves a provisioned SecretID.
4. Create each service's actual appsettings JSON payload using the application
   team's approved schema and secret-handling process. Store it in a root/user-
   only file with mode `0600`, then write it using the helper:

   ```bash
   chmod 0600 /secure/path/wallet-appsettings.json
   bash prod/write-vault-service-secret.sh wallet /secure/path/wallet-appsettings.json
   ```

   The helper sends the JSON through stdin to
   `kv/data/wallet/prod/appsettings`; payload contents are not command arguments
   or terminal output. Repeat with one file per service. No database users,
   passwords or appsettings fields are fabricated by this infrastructure.

   Use distinct service-scoped database logins where possible. Do not copy the
   shared RDS master credential into each app path; this infrastructure does not
   create application SQL users or infer the appsettings schema.
5. Update the application to authenticate with AppRole, read its own KV v2
   `appsettings` path, and bind the resulting data to its configuration. The
   application must understand KV v2's response envelope. Redeploy/verify the
   real service images before switching the infrastructure flag.
6. Only after every path, AppRole SecretID, and payload is ready, set
   `vault_secrets_enabled = true` and apply. ECS task definitions then inject
   each service's RoleID/SecretID from its own Secrets Manager ARN and stop
   injecting the RDS master DB_USER/DB_PASSWORD fields. The app must obtain its
   database credentials from Vault. If an app still relies on `DB_USER` or
   `DB_PASSWORD` environment variables, update its configuration first.

## SecretID rotation

Rotate one service after exposure or on the planned rotation schedule:

```bash
cd prod
bash configure-vault-services.sh --rotate wallet
```

The helper creates a replacement SecretID, writes the new bundle to Secrets
Manager, forces that ECS service to deploy and waits for it to become stable,
then revokes the previous SecretID. Already-issued Vault tokens can remain valid
until revoked or they expire (maximum 24 hours). `--rotate-all` rotates every
API service. Never copy a credential bundle between service secrets.

## Terraform outputs and controls

- `terraform output ecs_cluster_name`
- `terraform output ecs_service_names`
- `terraform output ecs_deployment_controller`
- `terraform output -json vault_service_access`

The last output contains only non-secret path/mount/environment metadata, the
Vault-mode Boolean, role/policy names, ECS service names and Secrets Manager
ARNs—not SecretIDs or application secret values. The AWS ECS
task execution role receives permission to retrieve the referenced credentials
when Vault mode is enabled; containers receive only the two fields declared in
their own task definition. The regular ECS task role is not used as Vault
identity in this AppRole design.
