# Agrovesto infrastructure (dev)
<!-- CI test suite check trigger -->

Terraform for the **dev** AWS account. The stack is a **single flat module in
this `dev/` folder** — there is no `modules/` or `environments/` tree. The
repo root holds a sibling `prod/` stack (ECS/RDS/ALB) and the two workflow
files (`dev.workflow.yml`, `prod.workflow.yml`).

```
dev/
├── versions.tf              # terraform block, backend, provider
├── variables.tf             # every input (single env + what used to be modules)
├── locals.tf                # naming, nginx upstreams, rendered templates, DNS maps
├── data.tf                  # AZs, Ubuntu 24.04 LTS AMI, IAM policy documents
├── vpc.tf                   # VPC + public subnet + IGW
├── security_groups.tf       # nginx (80/443) + SSH
├── s3_backup.tf             # versioned, encrypted MSSQL backup bucket
├── iam.tf                   # EC2 host role + EventBridge scheduler role
├── ec2.tf                   # app host, MSSQL data volume, Elastic IP
├── scheduler.tf             # start 08:00 / stop 20:00 (Africa/Lagos)
├── logging.tf               # EBS volume for the log/metric stores
├── host_config.tf           # S3 bucket holding every rendered file this box needs
├── amplify.tf               # frontends
├── route53.tf               # DNS (disabled: manage_dns=false — prod account owns the zone)
├── outputs.tf
├── terraform.auto.tfvars    # committed, secret-free values (auto-loaded)
├── user_data.sh.tftpl       # cloud-init bootstrap for the EC2 host (small on purpose)
├── docker-compose.yml.tftpl # nginx + APIs + Vault + MSSQL + logging stack
├── nginx.conf.tftpl         # one server block per subdomain
├── loki-config.yml.tftpl    alloy-config.alloy.tftpl    prometheus.yml.tftpl
├── grafana-datasources.yml.tftpl  grafana-dashboards.yml
├── grafana/dashboards/       # dev-logs.json, dev-host.json (provisioned, read-only)
├── tests/                   # terraform test suites (ec2, platform, logging)
├── checkov.yml  trivy.yml  trust-policy.json
└── ci-cd-quickstart.md
(../dev.workflow.yml is the CI/CD pipeline — see below)
```

## What gets created

| Piece | Details |
| --- | --- |
| Amplify | Two apps (`landing`, `onboarding`) with custom domains. Add a key in `amplify_apps` to create more. |
| VPC | Single public subnet + IGW (dev). |
| EC2 | Public subnet, Elastic IP, **nginx** reverse proxy. Root disk (OS + apps) + extra EBS (MSSQL data). |
| Docker on EC2 | 5 APIs, HashiCorp Vault (dev mode), SQL Server 2022 with 5 databases. Bind-mounted to the MSSQL disk. |
| Logging & metrics (on-host) | Alloy → Loki → Grafana for logs, Prometheus + cAdvisor + node-exporter for metrics, all as containers in the same compose project. Everything stays inside the instance — no CloudWatch, no EKS, no AWS ingestion or per-query charges. See **Logs and metrics** below. |
| EBS (logging) | 20 GB gp3 at `/opt/agrovesto/logging`: Loki chunks, the Prometheus TSDB and Grafana's sqlite. Survives an instance replacement. |
| Route 53 | **Managed from the prod account** (`manage_dns = false` here): dev hosts live under `dev.nomaos.com` (e.g. `wallet.dev.nomaos.com` → this host's EIP), created by the prod stack's `extra_a_records` / `extra_cname_records`. |
| S3 | Versioned, encrypted bucket for nightly MSSQL backups (cron on the instance). |
| EventBridge Scheduler | Start EC2 07:00, stop 20:00 every day (`Africa/Lagos`). |

Traffic path:

```
Internet → Route53 (zone owned by the PROD account)
            ├─ landing.dev / onboarding.dev  → Amplify
            └─ wallet.dev / onboarding-api.dev / input.dev / moneval.dev / serviceprovider.dev / vault.dev / mssql.dev
                                 → EIP → nginx (EC2) → docker containers
            dev-logs → nginx → Grafana (IP-allowlisted; empty allowlist = tunnel only)
```

## Adding more resources later

- **Another frontend** — add an entry under `amplify_apps` in `terraform.auto.tfvars`.
- **Another API** — add an entry under `apis` (`image`, `host_port`, `subdomain`). Nginx + DNS follow automatically.
- **Another MSSQL database** — append to `mssql_databases`.
- **A service that emits JSON logs** — add its compose service name to
  `logging.json_log_services`; Alloy then lifts `level`, `status`, `method` and
  `component` out of those lines into Loki labels. Plain-text services need
  nothing: they are already tailed, and `level` is read from the .NET prefix.
- **Extra DNS records** — use `extra_a_records`, `extra_cname_records` or `extra_alias_records` in `locals.tf`; they merge over the generated ones.
- **Another environment** — see the sibling `prod/` module (ECS/Fargate + RDS +
  ALB). For yet another account, copy `prod/` and change `project`,
  `environment`, `vpc_cidr` and the backend `key`.

## Apply (dev)

Run from this folder:

```bash
cd dev
cp terraform.tfvars.example terraform.tfvars   # optional local overrides
# edit domain, GitHub token, SA password, real API images
terraform init
terraform plan
terraform apply
```

DNS does not come from this stack: the prod account owns the zone. After a dev
apply, hand the `ec2_public_ip` and `frontend_default_domains` outputs to the
prod stack's `extra_a_records` / `extra_cname_records` (see
`prod/terraform.auto.tfvars`) so the `*.dev.nomaos.com` records point here —
then apply prod.

MSSQL SA password must meet SQL Server complexity rules. Vault root token in **dev** is `dev-root-token` (change via user-data / compose when you leave dev-mode).

## Logs and metrics

One variable switches the whole thing: `logging` in `terraform.auto.tfvars`
(`logging = { enabled = false }` removes the six containers, the volume and the
nginx vhost; the defaults in `variables.tf` are the shape of that object).

| Where | What |
| --- | --- |
| Loki | `127.0.0.1:3100` only. Stores container stdout/stderr, the nginx JSON access log and journald. Retention `loki_retention_days`, shorter for the noisy system streams via `system_retention_days`. |
| Alloy | the collector. Tails the docker json-file logs through `/var/run/docker.sock` (so no service needs a logging driver), reads `/var/log/journal` read-only, and accepts a push on `127.0.0.1:3101` for an app that would rather ship its own lines. |
| Grafana | `dev-logs.nomaos.com` through nginx, allowlisted to `logging.allowed_cidrs` (`[]` = localhost only). Two provisioned dashboards: *Agrovesto dev — logs* and *Agrovesto dev — host*. |
| Prometheus | `127.0.0.1:9090`, scraping node-exporter, cAdvisor, Loki, Alloy and Grafana. TSDB retention is time- **and** size-capped. |
| Volumes | `/opt/agrovesto/logging` on its own gp3, so Loki's churn does not compete with SQL Server for IOPS and the stores outlive the instance. |

Start with the outputs:

```bash
terraform -chdir=dev output grafana_url      # http://dev-logs.nomaos.com ("" if not exposed)
terraform -chdir=dev output logging_access    # ssh-tunnel + Loki/Prometheus/Alloy addresses
terraform -chdir=dev output logging_summary   # what is switched on, at what retention
```

With the committed default (`allowed_cidrs = []`) the vhost answers loopback
only, so take the tunnel the output already prints:

```bash
terraform -chdir=dev output logging_access         # ssh_tunnel, with the current EIP
IP=$(terraform -chdir=dev output -raw ec2_public_ip)
ssh -N -L 3000:127.0.0.1:3000 -L 3100:127.0.0.1:3100 -L 9090:127.0.0.1:9090 ubuntu@$IP
# then http://localhost:3000  (admin / logging.grafana_admin_password)
```

Without SSH ingress (if you tighten `allowed_ssh_cidrs`), Session Manager
forwarding reaches the same ports and needs no key:

```bash
aws ssm start-session --target "$(terraform -chdir=dev output -raw ec2_instance_id)" \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'
```

Useful LogQL against `{host="agrovesto-dev"}` — every stream also carries `job`
(`docker` / `journal`), container streams carry `service` (the compose service
name, e.g. `wallet`, `mssql`, `nginx`):

```logql
{service="wallet"} |= "fail"
{job="journal"} |= "ssh"
{component="nginx", status=~"5.."}
sum by (service) (count_over_time({host="agrovesto-dev"} [5m]))
{service="moneval"} | json | line_format "{{.message}}"
```

`status`, `method`, `component` and `level` are real Loki labels (the JSON stage in
`alloy-config.alloy.tftpl` promotes them), so they filter without parsing; the
URI, the client IP and the request body stay in the line, where `|~` and
`| json` still reach them. Keeping only those four indexed is deliberate —
indexing the URI would make every request its own series.

**Day 2, without Terraform.** Every rendered file on the host
(`compose/docker-compose.yml`, `nginx/nginx.conf`, the collectors' configs, the
dashboard JSON) arrives from `aws_s3_bucket.host_config` at boot, so editing a
file on the host and running `docker compose up -d` (or `restart <service>`) is
a legitimate way to experiment — it is what the box looked like before the first
`apply`. Two consequences to keep in mind:

- **A config change replaces the instance.** `user_data` carries the rendered
  bucket name, and `user_data` is immutable, so `terraform apply` after a
  `.tftpl` edit destroys and recreates the EC2 host. Both EBS volumes survive,
  so MSSQL data and the log stores survive with it; expect ~2 minutes of downtime
  and a fresh instance (new IMDS tokens, same EIP).
- **The next boot wins.** `aws s3 sync` never deletes (`--delete` would take
  Loki's chunks and the TSDB with it), but it does overwrite the config keys. An
  experiment you like has to end up in the template, or it is gone at the next
  replacement. Promote it with a commit; `dev/` CI applies on push.

The instance type is part of the deal: six extra containers, `t3.medium` →
**`t3.large`** in `terraform.auto.tfvars`. Revert it if the box is too busy by
day and too idle at night — the scheduler stops it outside 08:00–20:00
`Africa/Lagos`, so the delta is roughly the price of the extra two vCPU/RAM on a
~12 h/day schedule, and `terraform plan` shows the swap. Retention and the volume
size are the other two dials: `loki_retention_days` +
`loki_ingestion_rate_mb`/`loki_stream_rate_mb` bound the growth,
`volume_size_gb` bounds the disk; `loki_retention_days` shorter than the volume
can hold is the failure mode worth watching (`dev-host` dashboard, "Logging
volume" panel).

Nothing here talks to AWS-native services: no CloudWatch Logs or metrics, no
Container Insights, no Kinesis, and the instance role has no `logs:*` — the SSM
permissions in `data.tf` are there for Session Manager, not for logging. The one
AWS dependency is S3, for the read-only config pull described above.

## CI/CD (`dev.workflow.yml`)

The pipeline is authored at the repository root as **`dev.workflow.yml`** and
runs every Terraform command from this folder (`TF_WORKING_DIR: "dev"`).

- **Every run**: `terraform fmt -check -recursive`, Checkov and Trivy
  (SARIF → code scanning) and `terraform test` with a resource-coverage gate
  (`TF_COVERAGE_FAIL_UNDER`, 60 here). Nothing in the pipeline is
  `continue-on-error`, so a finding fails the job.
- **Pull requests** (to `dev`): a read-only `terraform plan` posted as a PR
  comment, plus an Infracost cost diff once `INFRACOST_API_KEY` is set.
- **Push to `dev`**: applies the dev stack after the same checks.
- SonarQube reports as its own project (`sonar-project-dev.properties`) and is
  skipped, with a warning, until `SONAR_TOKEN` exists.
- The runner needs AWS OIDC (`AWS_ROLE_ARN_DEV` secret). Non-secret required
  variables (`domain_name`, `amplify_apps`, `apis`, `mssql_databases`, …) are
  supplied by the committed `terraform.auto.tfvars`; the MSSQL SA password is
  injected via the `TF_VAR_MSSQL_SA_PASSWORD_DEV` secret.

Install it into GitHub Actions with:

```bash
cp dev.workflow.yml .github/workflows/dev.yml
```

> Heads-up: the checked-in `.github/workflows/dev.yml` still points at the old
> flat-repository layout and is now stale — replace it with
> `dev.workflow.yml` (the automation token has no `workflows` permission, so
> it cannot be updated by CI itself).

See `ci-cd-quickstart.md` for the full pipeline walkthrough
(secrets, variables, troubleshooting).

## Notes

- APIs listen on the docker network; nginx is the only public HTTP/S listener.
  The logging stack publishes nothing beyond `127.0.0.1` (Grafana and the APIs go
  through nginx or the tunnel), and the security group gets no new ingress rule.
- EC2 caps instance user data at 16 KB raw, which is why
  `user_data.sh.tftpl` is a bootstrap that syncs files rather than a script that
  contains them (`dev/host_config.tf`). Keep it that way when you add config:
  a rendered file becomes an entry in `local.host_config_files`, not a heredoc.
- Scheduler IAM can start/stop **any** instance in the account (`ec2:StartInstances` on `*`). Tighten the resource ARN if you add prod later.
- Amplify custom domains require the hosted zone in this account, so they stay off (`amplify_enable_custom_domain = false`); prod publishes the frontend CNAMEs instead (`landing.dev.nomaos.com` → Amplify default domain).
- Resource addresses changed when the tree was flattened (e.g. `aws_instance.app`
  instead of `module.ec2.aws_instance.this`). If you had a pre-existing state
  file, run `terraform state mv` (or import) before the first apply — see the
  migration table in `ci-cd-and-costs-quickstart.md`.
