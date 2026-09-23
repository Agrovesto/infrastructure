# Agrovesto Infrastructure

Comprehensive technical documentation for the Agrovesto AWS infrastructure. This repository uses Terraform to manage multiple environments (Dev, Prod, Monitoring) across separate AWS accounts using a flat-module structure.

## 📌 Project Overview

Agrovesto infrastructure is split into three primary logical blocks:
- **Dev (`dev/`)**: A cost-efficient single-EC2 environment running Docker Compose for 5 APIs, SQL Server, Vault, and a local observability stack.
- **Prod (`prod/`)**: A production-grade ECS Fargate environment with RDS SQL Server, HashiCorp Vault, and authoritative DNS.
- **Monitoring (`monitoring/`)**: An open-source observability stack (Prometheus, Loki, Tempo, Grafana) running in the Prod account to monitor production services without AWS-native costs.

---

## 📂 Repository Structure

```text
.
├── bootstrap/           # One-time manual setup: S3 state bucket, GitHub OIDC, Deploy role
├── dev/                 # Dev environment: EC2 + Docker (nginx, APIs, Vault, MSSQL, Observability)
├── prod/                # Prod environment: ECS Fargate + ECR + ALB + RDS SQL Server + Route53
├── monitoring/          # Observability: Prometheus, Loki, Tempo, Grafana (ECS Fargate + EFS)
├── scripts/             # Utility scripts (Infracost, Coverage, Tests, AWS discovery)
├── docs/                # Architecture diagrams (Mermaid) and narrative docs
├── tests/               # Documentation for the Terraform test suites
├── .github/workflows/   # CI/CD pipelines (dev.yml, prod.yml, monitoring.yml)
└── README.md            # You are here (Master Documentation)
```

---

## 🚀 Environments & Architecture

| Folder | Account | Stack | Networking | DNS |
| :--- | :--- | :--- | :--- | :--- |
| **Dev** | Dev | EC2 (t3.large) + Docker Compose | Single Public Subnet | `*.dev.nomaos.com` (managed by Prod) |
| **Prod** | Prod | ECS Fargate + RDS SQL Server | VPC (Pub/Priv/DB) + NAT | `nomaos.com` (Authoritative) |
| **Monitoring**| Prod | ECS Fargate + EFS | Private Subnets | `grafana.nomaos.com` |

### 🛠 Component Details

#### 1. Compute
- **Dev**: Runs on a single `t3.large` instance. Services are containerized via Docker Compose. The host is managed by a start/stop scheduler (08:00-20:00 Africa/Lagos) to save cost.
- **Prod**: 5 ECS Fargate services (ASPNETCORE APIs) running on Graviton (ARM64) for better price-performance. Scaling is managed via Application Auto Scaling (min 1, max 4).
- **Monitoring**: 5 always-on Fargate tasks (Prometheus, Loki, Tempo, Grafana, Edge) plus several scheduled batch jobs.

#### 2. Databases (SQL Server)
- **Dev**: SQL Server 2022 running as a container on the EC2 host. Backups are synced to S3.
- **Prod**: RDS SQL Server **Express** (`db.t3.micro`).
    - **Note**: Express has a 10GB per-database cap and no Multi-AZ support.
    - **Scaling**: Upgrade path to Web/Standard on `db.m7i.large` when Multi-AZ or >10GB is required.
    - **Init**: Databases are created via a one-off Fargate task triggered by Terraform (`run_db_init = true`).

#### 3. Secrets (HashiCorp Vault)
- Both environments use HashiCorp Vault.
- **Prod**: Fargate-based Vault with Raft storage on EFS and AWS KMS auto-unseal.
- **Migration**: Services can source secrets from AWS Secrets Manager (bootstrap) or switch to Vault (`vault_secrets_enabled = true`).

#### 4. Networking & DNS
- **Prod** account is authoritative for the root domain `nomaos.com`.
- **ALB**: Prod uses an internet-facing ALB with an ACM wildcard certificate.
- **NAT**: A single NAT Gateway is used in Prod to balance cost and redundancy.
- **Dev DNS**: Dev services are exposed via the Prod ALB or records in the Prod Route53 zone pointing to the Dev EIP.

---

## 📊 Observability (The Monitoring Stack)

The project deliberately avoids AWS-native observability (CloudWatch Alarms, Container Insights, X-Ray) to minimize costs. Instead, it uses an open-source stack:

- **Metrics**: Prometheus scrapes targets and stores metrics on EFS.
- **Logs**: Loki ingest logs from Docker (Dev) and CloudWatch Logs via a collector (Prod).
- **Traces**: Tempo handles OTLP traces.
- **Dashboards**: Grafana OSS provides unified visualization.
- **Alerts**: Alertmanager routes alerts to Email/Webhooks.

### Accessing Logs
- **Prod**: Reachable at `https://grafana.nomaos.com` (IP allowlisted via `grafana_allowed_cidrs`).
- **Dev**: Reachable at `dev-logs.nomaos.com` or via SSH tunnel:
  ```bash
  ssh -N -L 3000:127.0.0.1:3000 -L 3100:127.0.0.1:3100 -L 9090:127.0.0.1:9090 ubuntu@<DEV_EIP>
  ```

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
- **Scans**: Checkov and Trivy run on every PR. Suppressions are documented in `checkov.yml` and `trivy.yml`.

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

### Finding Resources That Are Not In Terraform (Discovery Scan)

`scripts/aws-inventory-scan.sh` scans both accounts read-only and reports what
exists in AWS versus what this repo manages, writing each account's report into
that environment's own folder:

```bash
./scripts/aws-inventory-scan.sh                 # both accounts -> dev/ and prod/
./scripts/aws-inventory-scan.sh --env dev       # one account
./scripts/aws-inventory-scan.sh --with-state    # also settle untaggable resources
```

- `dev/discovery/` — the dev account; `prod/discovery/` — the prod account;
  `monitoring/discovery/` — the monitoring rows of the prod-account scan;
  `.discovery/COMBINED.md` — the two side by side.
- Each folder holds a `SUMMARY.md` (start here), `inventory.csv`,
  `unmanaged.csv` (import candidates) and `imports/imports-<stack>.tf.txt`
  (ready-to-paste Terraform `import` blocks).
- "Managed" means the resource carries the `ManagedBy = terraform` default tag
  that all three stacks set; anything else is a candidate to adopt **or delete**.
- Read-only, no secret values are fetched, and the output is gitignored (it
  contains account IDs and IP addresses).

Full walkthrough — including the import procedure with
`terraform plan -generate-config-out` and the cost/security/hygiene findings the
scan reports — is in [docs/discovery.md](docs/discovery.md).

### Manual RDS Init
If `run_db_init = true` is not used, connect to the DB and run:
```sql
IF DB_ID('wallet') IS NULL CREATE DATABASE [wallet];
-- Repeat for onboarding, input, moneval, serviceprovider
```

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
