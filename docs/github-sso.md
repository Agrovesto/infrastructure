# GitHub login for Grafana and SonarQube

The infrastructure supports GitHub login without removing the local administrator
accounts. GitHub login is for people using the web UIs; scanners still use
`SONAR_TOKEN` and `SONAR_HOST_URL`.

## Login before GitHub SSO is configured

| Service | URL | Login |
| --- | --- | --- |
| SonarQube Community Build | `http://sonar.nomaos.com` (or the SSH tunnel) | On a fresh database, `admin` / `admin`; SonarQube immediately requires a password change. The changed password is held by SonarQube, not Terraform or SSM. |
| Production Grafana | `https://grafana.nomaos.com` | Configured admin user (default `admin`); generated password in SSM SecureString `/agrovesto-monitoring/grafana/admin-password`. |
| Dev Grafana | `http://dev-logs.nomaos.com` (or the SSH tunnel) | Configured admin user (default `admin`); password in SSM SecureString `/agrovesto-dev/grafana_admin_password` (the dev-only default is `agrovesto-dev` unless overridden). |

Retrieve a Grafana break-glass password with an authenticated AWS CLI in the
corresponding account:

```bash
aws ssm get-parameter \
  --name /agrovesto-monitoring/grafana/admin-password \
  --with-decryption --query Parameter.Value --output text --region eu-west-1

aws ssm get-parameter \
  --name /agrovesto-dev/grafana_admin_password \
  --with-decryption --query Parameter.Value --output text --region eu-west-1
```

Do not paste either password into an issue, PR, workflow log, or chat.

## What is implemented

- **Dev and production Grafana OSS:** native GitHub OAuth. Production Grafana is
  implemented by the `monitoring/` stack (not `prod/`) and receives its own OAuth
  App credentials through the monitoring job in `workflows/prod.yml`. Both
  instances evaluate GitHub team membership on every login and reject members
  of `Agrovesto` who are not in an explicitly mapped team. Basic login stays
  enabled for the configured local administrator break-glass account.
- **SonarQube Community Build:** native GitHub App authentication with
  just-in-time user provisioning. Only members of `Agrovesto` may sign in, and
  GitHub team-to-SonarQube group synchronization is enabled. The local
  administrator stays enabled.
- **Dev HTTPS:** SonarSource does not permit an HTTP GitHub callback. When either
  dev identity provider is configured, a pinned Caddy container takes ownership
  of public ports 80/443, obtains and renews certificates, and forwards to the
  existing nginx router. nginx continues to enforce the configured source-IP
  allowlists. Caddy's ACME state is kept on encrypted persistent EBS.
- **Secrets:** Terraform receives credentials from repository GitHub Actions
  secrets and writes them to KMS-encrypted SSM SecureStrings. No credential is
  rendered into S3 host config or EC2 user data. As with the existing SSM
  password resources, sensitive Terraform values are still present in the
  encrypted remote Terraform state; access to that state must remain restricted.

Supplying a complete credential set enables its provider automatically. Leaving
all fields empty preserves local-only login. A partial set fails the Terraform
resource precondition.

## 1. Register the SonarQube GitHub App

Create a **private GitHub App** owned by `Agrovesto`:

- Homepage URL: `https://sonar.nomaos.com`
- User authorization callback URL: `https://sonar.nomaos.com`
- Webhooks: disabled
- Organization permissions → Members: read-only
- Account permissions → Email addresses: read-only
- Install it on the `Agrovesto` organization.

Generate a private key and retain its PEM file securely. Configure these
repository Actions secrets (the reusable plan job does not inherit GitHub
Environment secrets):

```text
SONARQUBE_GITHUB_CLIENT_ID
SONARQUBE_GITHUB_CLIENT_SECRET
SONARQUBE_GITHUB_APP_ID
SONARQUBE_GITHUB_PRIVATE_KEY
```

The private-key secret must contain the complete PEM, including its BEGIN/END
lines. It can be loaded without printing it:

```bash
gh secret set SONARQUBE_GITHUB_PRIVATE_KEY < path/to/github-app.private-key.pem
```

The workflow maps these to the sensitive `sonarqube_github_*` Terraform
variables. At boot, the dev host fetches their SSM values and writes
`/opt/agrovesto/sonarqube/sonar-sso.properties` as mode `0600`, owned by the
SonarQube container UID.

## 2. Register Grafana OAuth Apps

Use separate OAuth Apps because prod and dev have different callback URLs.

### Production Grafana

- Homepage URL: `https://grafana.nomaos.com`
- Authorization callback URL: `https://grafana.nomaos.com/login/github`
- Secrets:
  - `GRAFANA_GITHUB_CLIENT_ID`
  - `GRAFANA_GITHUB_CLIENT_SECRET`

### Dev Grafana

- Homepage URL: `https://dev-logs.nomaos.com`
- Authorization callback URL: `https://dev-logs.nomaos.com/login/github`
- Secrets:
  - `DEV_GRAFANA_GITHUB_CLIENT_ID`
  - `DEV_GRAFANA_GITHUB_CLIENT_SECRET`

Grafana requests `user:email,read:org`; the latter is required to enforce the
`Agrovesto` organization restriction and retrieve team membership. If the
organization restricts third-party OAuth Apps, an organization owner must approve
both apps.

## 3. Team roles

The same team policy applies to dev Grafana, production Grafana, and SonarQube:

| GitHub team | Grafana role | SonarQube role |
| --- | --- | --- |
| `Backend` (`backend`) | Viewer (read) | Browse and see source |
| `Frontend` (`frontend`) | Viewer (read) | Browse and see source |
| `Infrastructure` (`infrastructure`) | Organization Admin | System and project Admin |
| `mobile` (`mobile`) | Viewer (read) | Browse and see source |
| `team-leads` (`team-leads`) | Editor (read/write) | Browse, see source, administer issues, and administer security hotspots |

Grafana's ordered JMESPath mapping checks `Infrastructure` first, then
`team-leads`, then the reader teams, so a user in several teams receives the
highest listed role. `Admin` is a Grafana **organization** role;
`allow_assign_grafana_admin=false` prevents OAuth from granting unrestricted
Grafana server-administrator access. Strict role mapping denies login to an
`Agrovesto` member who is not in one of these five teams.

SonarQube synchronizes memberships only into groups that already exist, and its
authentication configuration cannot create or grant those groups. After the
first SSO deployment, run the shipped idempotent bootstrap with a dedicated
SonarQube global-administrator token (not the CI analysis `SONAR_TOKEN`):

```bash
ssh ubuntu@<DEV_EIP>
read -rsp 'SonarQube admin token: ' SONAR_ADMIN_TOKEN
export SONAR_ADMIN_TOKEN
sudo --preserve-env=SONAR_ADMIN_TOKEN \
  /opt/agrovesto/scripts/configure-sonarqube-team-permissions.sh
unset SONAR_ADMIN_TOKEN
```

The script creates the case-sensitive `Agrovesto/Team` groups, grants the matrix
to every existing project without replacing unrelated grants, and makes the same
matrix the default permission template for future projects. Treat membership in
the GitHub `Infrastructure` team as privileged: it confers SonarQube system
administrator access.

## 4. Network prerequisites

GitHub SSO does not bypass either service's network allowlist.

- Set `monitoring.grafana_allowed_cidrs` to office/VPN egress CIDRs, or access
  production Grafana from the VPC. Its default `[]` permits VPC traffic only.
- Set `dev.logging.allowed_cidrs` and `dev.sonarqube.allowed_cidrs` to the
  office/VPN egress CIDRs before supplying dev SSO credentials. Terraform rejects
  dev SSO with an empty allowlist.
- Ensure `grafana.nomaos.com`, `dev-logs.nomaos.com`, and `sonar.nomaos.com`
  resolve to the endpoints documented in the stack outputs. Caddy needs the two
  dev records to reach the dev Elastic IP before ACME can issue certificates.
- Ports 80 and 443 are already present in the dev security group. Do not add
  Grafana port 3000 or SonarQube port 9000 to public ingress.

GitHub-hosted Actions runners also need network access to SonarQube for scanning.
SSO does not solve that separate scanner reachability requirement; use a
self-hosted runner or fixed allowlisted NAT egress.

## 5. Rollout and verification

1. Register/install the apps and configure all required GitHub secrets. Copy the
   reviewed root workflow sources into `.github/workflows/` using an identity
   with GitHub Workflows permission before running the deployment.
2. Configure the source CIDRs and the two dev DNS records.
3. Review the plans carefully. Enabling dev SSO changes immutable EC2 user data,
   so the dev instance is replaced. Its MSSQL, logging, and SonarQube EBS volumes
   survive, but expect several minutes of downtime. Production Grafana in the
   monitoring stack performs an ECS rolling deployment.
4. After apply, run the SonarQube team-permission bootstrap above, then inspect
   the explicit outputs:

   ```bash
   terraform -chdir=dev output sonarqube_authentication
   terraform -chdir=dev output grafana_authentication
   terraform -chdir=monitoring output grafana_authentication
   ```

5. Open each URL and select **Sign in with GitHub** / **Log in with GitHub**.
   Confirm members of each mapped team receive the table's role, an unlisted
   `Agrovesto` member is denied by Grafana, and a non-member cannot sign in.
6. Confirm a `team-leads` user can update issues but cannot administer SonarQube,
   and verify `Infrastructure` membership with a separate test account before
   relying on its administrator mapping.
7. Test the local admin accounts before treating SSO as operational. They are the
   recovery path for an OAuth outage or a bad organization policy.
8. Keep `SONAR_TOKEN` in Actions and run a scan. A successful browser login does
   not authenticate CI.

For local Terraform runs, provide the same values through
`TF_VAR_grafana_github_client_id`, `TF_VAR_grafana_github_client_secret`, and the
four `TF_VAR_sonarqube_github_*` variables; never put them in a `.tfvars` file.
Rotating a repository secret and rerunning the workflow creates a new SSM
parameter version; that version deliberately triggers a dev host replacement or
production Grafana task revision so the running service reads the new value.
