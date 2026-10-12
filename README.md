# Agrovesto Infrastructure

Comprehensive technical documentation for the Agrovesto AWS infrastructure. This repository uses Terraform to manage multiple environments (Dev, Prod, Monitoring) across separate AWS accounts using a flat-module structure.

## 📌 Project Overview

Agrovesto infrastructure is split into three primary logical blocks:
- **Dev (`dev/`)**: A cost-efficient single-EC2 environment running Docker Compose for 7 APIs, SQL Server, Redis, SonarQube, Vault, and a local observability stack.
- **Prod (`prod/`)**: A production-grade ECS Fargate environment with RDS SQL Server, HashiCorp Vault, and authoritative DNS. Services export OpenTelemetry traces and metrics to the monitoring stack.
- **Monitoring (`monitoring/`)**: An open-source observability stack (Prometheus, Loki, Tempo, Grafana) running in the Prod account to monitor production services without AWS-native costs.

---

## 📂 Repository Structure

```text
.
├── bootstrap/           # One-time manual setup: S3 state bucket, GitHub OIDC, Deploy role
├── dev/                 # Dev environment: EC2 + Docker (nginx, APIs, Vault, MSSQL, Redis, SonarQube, Observability)
├── prod/                # Prod environment: ECS Fargate + ECR + ALB + RDS SQL Server + Route53 + OpenTelemetry export
├── monitoring/          # Observability: Prometheus, Loki, Tempo, Grafana (ECS Fargate + EFS)
├── scripts/             # Utility scripts (Infracost, Coverage, Test suites)
├── docs/                # Architecture diagrams (Mermaid), narrative docs, team.md
├── tests/               # Documentation for the Terraform test suites
├── .github/
│   ├── workflows/       # CI/CD pipelines (dev.yml, prod.yml, terraform-pipeline.yml)
│   ├── CODEOWNERS       # Who reviews what (teams, not individuals)
│   └── PULL_REQUEST_TEMPLATE.md  # Replacements, cost, rollout, verification
└── README.md            # You are here (Master Documentation)
```

---

## 🚀 Environments & Architecture

| Folder | Account | Stack | Networking | DNS |
| :--- | :--- | :--- | :--- | :--- |
| **Dev** | Dev | EC2 (t3.large) + Docker Compose | Single Public Subnet | `dev-*.nomaos.com` + `sonar.nomaos.com` (records created in the Prod zone) |
| **Prod** | Prod | ECS Fargate + RDS SQL Server | VPC (Pub/Priv/DB) + NAT | `nomaos.com` (Authoritative) |
| **Monitoring**| Prod | ECS Fargate + EFS | Private Subnets | `grafana.nomaos.com` |

### 🛠 Component Details

#### 1. Compute
- **Dev**: Runs on a single `t3.large` instance. Services are containerized via Docker Compose: nginx, 7 APIs, SQL Server, **Redis**, **SonarQube**, Vault and 8 observability containers. The host is managed by a start/stop scheduler (08:00-20:00 Africa/Lagos) to save cost.
- **Prod**: 5 ECS Fargate services (ASPNETCORE APIs) running on Graviton (ARM64) for better price-performance. Scaling is managed via Application Auto Scaling (min 1, max 4).
- **Monitoring**: 5 always-on Fargate tasks (Prometheus, Loki, Tempo, Grafana, Edge) plus several scheduled batch jobs.

#### 2. Databases (SQL Server)
- **Dev**: SQL Server 2022 runs as a container on the EC2 host for the five managed API databases, backed up to S3. The migrated `agx` database is not created by this stack; confirm separately whether it lives on this SQL host and needs inclusion in backups. SonarQube currently uses its own PostgreSQL container (the optional MSSQL path creates `sonar` with the required CS_AS collation and snapshot isolation).
- **Prod**: RDS SQL Server **Express** (`db.t3.micro`).
    - **Note**: Express has a 10GB per-database cap and no Multi-AZ support.
    - **Scaling**: Upgrade path to Web/Standard on `db.m7i.large` when Multi-AZ or >10GB is required.
    - **Init**: Databases are created via a one-off Fargate task triggered by Terraform (`run_db_init = true`).

#### 3. Caching & Code Quality (Dev)
- **Redis**: `redis:6379` on the compose network for the APIs, published on the host's loopback only. Bounded at 256 MB with `allkeys-lru` eviction, because SQL Server shares the box and an unbounded cache is what takes the APIs down. No AUTH and no persistence by default; both are one flag away (`var.redis`).
- **SonarQube**: Community Build on its own EBS volume, backed by its on-host PostgreSQL container. This is the server CI pushes to via `SONAR_HOST_URL`. Served by nginx at `sonar.nomaos.com`, IP-gated the same way the Grafana vhost is.
    - **Memory**: SonarSource asks for 4 GB; this host has 8 GiB and SQL Server is on it. Elasticsearch therefore runs on a 1 GB heap inside a 3 GB cgroup limit, so a heavy analysis kills SonarQube rather than the kernel OOM-killing the database. `t3.xlarge` is the fix if that starts happening.
    - **Kernel**: `vm.max_map_count=262144` is written to `/etc/sysctl.d` at boot — Elasticsearch fails a hard bootstrap check without it.

#### 4. Secrets (HashiCorp Vault)
- Both environments use HashiCorp Vault.
- **Dev**: After the instance rebuild, the checked-in configuration opts into a fresh Vault with a protected, encrypted dedicated EBS volume, KMS auto-unseal configuration and daily crash-consistent snapshots. Terraform/SSM prepares the host but never initializes Vault or captures recovery keys. Apply and verify before initializing; see the [fresh setup and recovery runbook](docs/vault-fresh-setup.md). Existing root-disk installations must not enable this as a migration.
- **Prod**: Fargate-based Vault with Raft storage on EFS and AWS KMS auto-unseal.
- **Migration**: Services can source secrets from AWS Secrets Manager (bootstrap) or switch to Vault (`vault_secrets_enabled = true`).

#### 5. Networking & DNS
- **Prod** account is authoritative for the root domain `nomaos.com`.
- **ALB**: Prod uses an internet-facing ALB with an ACM wildcard certificate.
- **Dev blue/green deploys**: every dev API serves its deploys on its own hostname — `deploy.sh` (`--app <key>-api`) flips slots behind `dev-wallet-api.nomaos.com` & co; Terraform ships the default blue slot file per API and boot seeds it. Port table, slot-file contract and `deploy.sh` requirements: `docs/blue-green-deployments.md`.
- **Dev agx API**: `agx` is an additional Compose service on port 5006, routed by nginx at `dev-agx-api.nomaos.com`, with its own ECR repository. The agx database was already migrated; this stack does not create a new one. Its image is still the placeholder nginx image; replace it with the real API image and add `dev-agx-api` to prod-managed `extra_a_records` to make the name resolve.
- **Dev agx frontend**: `agx-frontend` is a manual Amplify placeholder on the `dev` branch. There is no source repository or deployed build yet, so auto-build and DNS publication for the reserved `dev-agx.nomaos.com` hostname are disabled. When the real frontend exists, set its `repository`, enable auto-build, set `publish_dns = true`, and add the CNAME in the prod-owned zone (or deploy artifacts manually).
- **NAT**: A single NAT Gateway is used in Prod to balance cost and redundancy.
- **Dev DNS**: Dev services are exposed via the Prod ALB or records in the Prod Route53 zone pointing to the Dev EIP.

---

## 📊 Observability (The Monitoring Stack)

The project uses CloudWatch alarms for Dev and Prod infrastructure alerts, while the monitoring stack uses open-source tooling for application metrics, logs, traces, and alert routing. Container Insights and X-Ray are not enabled:

- **Metrics**: Prometheus scrapes targets and stores metrics on EFS. Prod services also push their own OTLP metrics through Alloy into Prometheus (remote write). One scheduled Fargate collector (`rate(2 min)`, ARM64, 0.25 vCPU / 0.5 GB) runs the enabled collector scripts in sequence and pushes to pushgateway: ECS service and task state, the always-free basic CloudWatch metrics (ECS service CPU/memory, RDS CPU/memory/disk/connections, ALB requests/latency/5xx, NAT bytes, EFS burst credits) and its own health. Container Insights and X-Ray stay off — the basic metrics answer the same questions at $0, and the extra scripts run in the task that already existed.
- **Logs**: Loki ingests docker logs on the dev host (Alloy) and, in prod, application logs read out of CloudWatch Logs plus ALB access logs read straight out of the access-log bucket — one Loki line per request, labelled with `service`, `status`, `method`, with the client IP, user agent, URI and timings in the line for LogQL to unwrap. Both shippers publish counters and a newest-event timestamp, so a pipeline that stops delivering raises an alert instead of leaving an empty dashboard.
- **Traces**: Tempo handles OTLP traces. The receiving side has always been there; the sending side is now wired too — every prod ECS task definition carries `OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy.monitoring.internal:4317` and the sampler/exporter settings, so traces flow the moment an image loads an OTel SDK. See `var.otel` in `prod/variables.tf`.
    - **Still required in the application image**: the OTLP exporter is a library, not a sidecar. For the ASP.NET APIs that means `OpenTelemetry.Extensions.Hosting`, `OpenTelemetry.Exporter.OpenTelemetryProtocol` and the ASP.NET Core / HttpClient / SqlClient instrumentation packages. The environment variables are inert until then.
    - **Logs stay on the awslogs driver** (`OTEL_LOGS_EXPORTER=none`): exporting them over OTLP as well would store every line in CloudWatch *and* Loki.
    - **Dev mirrors the same path on the host**: every compose API gets the identical `OTEL_*` env block pointed at `http://alloy:4317` (`local.otel_environment` in `dev/locals.tf`), Alloy forwards spans to an on-host Tempo container (14-day retention on the logging EBS volume, span metrics remote-written to the host Prometheus), and Grafana's Tempo↔Loki links are provisioned. Same caveat: inert until the image loads an OTel SDK.
- **Dashboards**: Grafana OSS provides unified visualization, with trace-to-log jumps from Tempo to Loki already wired. Dashboards are provisioned from this repo as JSON files and Grafana re-reads them every 30 s, so an edit made in the UI is reverted — dashboard changes land as a commit.
    - **Prod**: `platform`, `services`, `cost`, `ecs` (per-service CPU/memory and task state), `resources` (ECS, EC2, RDS, NAT, EFS, ALB), `traffic` (requests per service, status classes, latency, client IPs, user agents).
    - **Dev**: `dev-host`, `dev-logs`, `dev-services` (per-container CPU, memory against limit, throttling, restarts), `dev-traffic` (nginx request volume by vhost, URI, client and user agent), `dev-infra` (the dockerized data tier — MSSQL, Redis, RabbitMQ, SonarQube, Vault — plus the observability containers themselves).
- **Alerts**: Prometheus evaluates the resource rules and Loki's ruler evaluates the log rules in both stacks; Alertmanager groups, inhibits and routes. Delivery is SNS with sigv4 — prod to `agrovesto-prod-alerts` (`var.alertmanager_sns_topic`), dev to the dev alerts topic, which e-mails `var.alert_emails` (`tech@agrovesto.com`). The SMTP and webhook receivers stay empty on purpose.
    - **Loki rule files must sit in the tenant directory**: the local rule store reads `<rules dir>/<tenant>/<namespace>.yml`, and with `auth_enabled: false` the tenant is literally `fake`. Both stacks therefore publish `loki/rules/fake/application.yml`; a file one level up is never loaded and the ruler stays silent about it.

### Accessing Logs
- **Prod**: Reachable at `https://grafana.nomaos.com` (IP allowlisted via `grafana_allowed_cidrs`).
- **Dev**: Reachable at `http://dev-grafana.nomaos.com` without SSO, `https://dev-grafana.nomaos.com` when GitHub SSO is configured, or via SSH tunnel:
  ```bash
  ssh -N -L 3000:127.0.0.1:3000 -L 3100:127.0.0.1:3100 -L 9090:127.0.0.1:9090 ubuntu@<DEV_EIP>
  ```

**Login:** production Grafana uses the configured admin user (default `admin`)
plus the generated password in SSM
`/agrovesto-monitoring/grafana/admin-password`; dev Grafana uses its configured
admin user (default `admin`) plus `/agrovesto-dev/grafana_admin_password`. A
fresh SonarQube database starts as `admin` / `admin` and forces a first-login
password change. GitHub login is enabled when the credential sets documented
in [`docs/github-sso.md`](docs/github-sso.md) are supplied; local admin stays
enabled as a break-glass path. Both Grafana instances map `Infrastructure` to
Admin, `team-leads` to Editor, and `Backend`, `Frontend`, and `mobile` to Viewer;
SonarQube synchronizes the corresponding groups and applies the documented
least-privilege permission matrix.

### Accessing SonarQube and Redis (Dev)
Both publish loopback ports only and have no security-group ingress, so the
tunnel is the way in. `terraform -chdir=dev output sonarqube_access redis_access`
prints the exact commands.

```bash
# SonarQube UI (first login is admin/admin, then it forces a password change).
# First boot takes 2-5 minutes on a 1 GB Elasticsearch heap.
ssh -N -L 9000:127.0.0.1:9000 ubuntu@<DEV_EIP>

# Redis, for redis-cli against the shared cache.
ssh -N -L 6379:127.0.0.1:6379 ubuntu@<DEV_EIP>
```

> **Before pointing CI at SonarQube**: `sonarqube.allowed_cidrs` defaults to `[]`,
> which makes the nginx vhost answer `127.0.0.1` only. GitHub-hosted runner
> addresses are not a fixed set, so "allow GitHub Actions" cannot be expressed as
> a CIDR list — use a self-hosted runner or an allowlisted NAT egress. Until one
> of those is in the list, scanners are denied at the edge and the
> `SONAR_HOST_URL` secret will not be reachable.
>
> GitHub SSO is supported for SonarQube and both Grafana instances. A complete
> dev credential set adds a Caddy TLS edge automatically, because SonarSource
> requires an HTTPS callback; production Grafana already terminates HTTPS at the
> ALB. Access is still restricted by each service's CIDR allowlist, and CI still
> uses `SONAR_TOKEN` rather than browser SSO. Registration, callback URLs, secret
> names, fallback logins and rollout steps are in
> [`docs/github-sso.md`](docs/github-sso.md).

---

## 🏗 CI/CD Pipeline

Workflows in `.github/workflows/` manage automated deployments:

1. **Lint & Scan**: `terraform fmt`, Checkov (Security), Trivy (Vulnerabilities/Secrets).
2. **Test & Coverage**: `terraform test` with mock AWS provider.
    - **Dev**: 60% coverage gate.
    - **Prod**: 70% coverage gate.
    - **Monitoring**: 95% coverage gate.
3. **SonarQube**: Code quality analysis.
4. **Plan**: Infracost cost estimates + Terraform Plan (posted to PR).
5. **Apply**: Automated apply on merge to `dev` (Dev) or `main` (Prod/Monitoring).

---

## 🔒 Security & Compliance

- **OIDC**: GitHub Actions assumes IAM roles via OIDC (no long-lived AWS keys).
- **Encryption**: All S3 buckets, EFS volumes, and EBS disks are encrypted (AES256 or KMS).
- **Scans**: Checkov and Trivy run on every PR. Suppressions are documented in each stack's `checkov.yml` and `.trivyignore.yaml`.

---

## 💰 Cost Management

Total stack cost is roughly **~$250-$300/month**.
- **Dev**: ~$30/mo (Scheduled t3.large + EBS).
- **Prod**: ~$150/mo (ECS Fargate + RDS Express + NAT + ALB).
- **Monitoring**: ~$95/mo (ECS Fargate + EFS).

Use `./scripts/infracost.sh` to generate a full cost report (requires `INFRACOST_API_KEY`).

---

## 🛠 Operational Workflows

### One-Time Bootstrap (New Account)
1. Navigate to `bootstrap/`.
2. Run `terraform apply` with admin credentials.
3. Follow the `next_steps` output to configure the GitHub Role ARN and backend bucket.

### Onboarding a New Service
1. Add the service to the `services` (Prod) or `apis` (Dev) map in `terraform.auto.tfvars`.
2. Push the Docker image to the ECR repo created by Terraform.
3. Update the `image` tag in Terraform and apply.
4. (Optional) Add a Blackbox probe in `monitoring/terraform.auto.tfvars`.

What the service gets for free, without further configuration:

- **Redis (Dev)**: `REDIS_HOST=redis` / `REDIS_PORT=6379` are injected into every
  API container in the map, so a new service reaches the shared cache by name.
- **OpenTelemetry (Prod)**: `OTEL_SERVICE_NAME` is set to the service key
  automatically, along with the endpoint, sampler and exporter settings from
  `var.otel`. Nothing per-service to add — but the image still has to load an OTel
  SDK for anything to be exported.
- **Database**: the service key is used as the database name in both environments
  (`DB_NAME`), and in Dev it is created by `init-dbs.sql` and included in the
  nightly S3 backup once it appears in `mssql_databases`.

### Manual RDS Init
If `run_db_init = true` is not used, connect to the DB and run:
```sql
IF DB_ID('wallet') IS NULL CREATE DATABASE [wallet];
-- Repeat for onboarding, input, moneval, serviceprovider
```

The dev host's `sonar` database is **not** a plain create — SonarQube requires a
case- and accent-sensitive collation and snapshot isolation, and neither can be
changed after data exists:

```sql
IF DB_ID('sonar') IS NULL CREATE DATABASE [sonar] COLLATE SQL_Latin1_General_CP1_CS_AS;
GO
ALTER DATABASE [sonar] SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
```

Terraform renders exactly this (plus a least-privilege login scoped to `db_owner`
of that one database) into `scripts/init-dbs.sql`, so the manual route is only
needed when `run_db_init` is off in prod or the dev bootstrap has to be re-run by
hand: `/opt/agrovesto/scripts/init-mssql.sh`.

---

## 🧪 Local Development

```bash
# Initialize without backend (for local tests/validation)
terraform init -backend=false

# Run native tests
terraform test

# Check resource coverage
python3 scripts/tf_coverage.py <folder>
```

---

## 📄 License & Notes
- This infrastructure is managed by Agrovesto.
- **State Locking**: Currently relies on GitHub Action concurrency groups.
- **Terraform Version**: Required `>= 1.7.0` (pinned to `1.10.5` in CI).
