# Narrative

Companion to `architecture.mmd` (runtime and boundaries), `telemetry.mmd`
(telemetry and cost flow) and `cicd.mmd` (pipelines and state). All figures are
eu-west-1 list price for a full month, taken from the inventory: dev ≈ $29,
prod application ≈ $154, monitoring ≈ $107 (counted under prod), estate
≈ $290. Nothing here is estimated twice — components the price list cannot
describe are listed separately at the end.

## Data paths

### User request path — prod APIs

- Browser resolves `wallet-api.nomaos.com` (and its four siblings) against
  Route53, which holds both hosted zones (`nomaos.com`, `agrovesto`); the alias
  records point at the Application Load Balancer.
- The browser opens TLS to `agrovesto-prod-alb` on 443, using a wildcard
  `*.nomaos.com` certificate from ACM. Port 80 is answered with a redirect to
  443, never with content.
- The load balancer picks one of two target groups: `services` (the five APIs,
  host-based rules) or `vault`.
- Traffic reaches the Fargate task on the port the service listens on —
  wallet 5001, onboarding 5002, input 5003, moneval 5004, serviceprovider 5005.
  Tasks are ARM64, 256 vCPU / 512 MiB, desired count 1, scaling to 4 at 1000
  requests per task.
- Each API opens TDS 1433 to RDS SQL Server Express in the database subnet and
  reads its master credentials once at start-up from Secrets Manager over HTTPS
  `GetSecretValue`.

### User request path — prod dashboards

- `grafana.nomaos.com` resolves to the same load balancer, matched by a
  dedicated listener rule and target group, then to Grafana on 3000.
- `grafana_allowed_cidrs` is empty, so the security group admits the VPC range
  only: the name resolves publicly, the endpoint does not answer publicly.

### User request path — dev

- The dev APIs and front ends use `dev.nomaos.com` style hostnames that live in
  the **prod** zone; dev runs `manage_dns = false` and creates no zone of its
  own. Those records are filled from dev stack outputs after an apply.
- Traffic lands on the dev Elastic IP and is terminated by nginx 1.27-alpine on
  the t3.medium host, which forwards to the five containers on 5001–5005.
- The React front ends never touch the host: Amplify serves them from its CDN,
  with two branches and domains attached.

### Log path

- Container stdout from every prod API task and every monitoring component goes
  to CloudWatch Logs through the `awslogs` driver, 30-day retention.
- Application logs that need log search take a different route: services POST to
  Alloy in the edge task — Loki push API on 3100 — which forwards to Loki, kept
  30 days on EFS.
- The monitoring stack's own logs stay in CloudWatch Logs; they are not
  duplicated into Loki, so a broken ingest path is still visible.

### Metric path

- Prometheus scrapes in-VPC endpoints found through Cloud Map
  (`monitoring.internal`, A records with a 10 s TTL): Loki 3100, Tempo 3200,
  Grafana 3000, the edge task's Alloy 12345, blackbox 9115, pushgateway 9091.
  Retention is 15 days.
- Traces become metrics: Tempo's metrics-generator remote-writes span metrics to
  Prometheus, so request rates and latencies appear without an agent.
- Batch work pushes instead of being scraped: the collector (every 2 minutes,
  ECS `DescribeServices`/`DescribeTasks` over HTTPS), the SQL Server metrics job
  (hourly, TDS 1433 DMV read using the master secret), the budget job (daily
  06:15 UTC) and the monthly report job (08:00 UTC on the 1st) all push to
  pushgateway on 9091.
- Grafana queries Prometheus 9090, Loki 3100 and Tempo 3200 as datasources, and
  reads its admin password from SSM Parameter Store over HTTPS.

### Trace path

- Applications send OTLP to Alloy (4317 gRPC, 4318 HTTP) in the edge task.
- Alloy forwards spans to Tempo (OTLP 4317). Tempo stores blocks on EFS for 14
  days and emits span metrics back into Prometheus.

### Alert path

- Prometheus evaluates alert rules and pushes them to Alertmanager on 9093,
  inside the same edge task.
- Alertmanager groups and routes, but every receiver is empty
  (`alert_email`, `alert_smtp_host`, `alertmanager_webhook_url`), so today an
  alert ends inside the stack and is only visible in Grafana. The rules cover
  ECS task and service state plus the SQL Server size signal.
- The SQL Server 8 GiB warning threshold travels the same route: the hourly job
  publishes `mssql_database_size_bytes` and the Alertmanager rule compares it
  with `mssql_database_size_warning_bytes`.
- The native alternative — CloudWatch metric filter, metric alarm, SNS e-mail —
  exists in the prod root but is disabled (`db_size_alarm_enabled = false`), so
  there is no native path to page anyone either.

### Cost path

- AWS writes the Cost and Usage Report as daily Parquet into the CUR bucket in
  **us-east-1** (the only resource outside eu-west-1).
- The budget task runs daily at 06:15 UTC, reads the Parquet with DuckDB in
  place, and pushes budget metrics to pushgateway.
- Prometheus scrapes pushgateway; Grafana renders the budget dashboard and
  raises the 80 % alert against the $250 monthly budget.
- On the 1st at 08:00 UTC the report task aggregates the previous two months,
  renders a PDF with fpdf2, mails it through SES, and pushes the closed-month
  cost metrics so a finished month stays visible after the CUR window moves on.
- SES sends from a domain verified by Terraform (identity plus three DKIM CNAMEs
  in Route53); the account is still in the SES sandbox, so mail only reaches
  verified addresses until production access is granted.

### CI/CD path

- A push or pull request touching `dev/**`, `prod/**` or `monitoring/**`
  triggers exactly one pipeline; nothing else does.
- Each pipeline runs the same chain: `terraform fmt -check -recursive`, checkov
  and trivy, `terraform test` with `mock_provider` (no AWS credentials) and a
  95 % resource-coverage gate, a SonarQube scan of that folder, an Infracost
  cost comment, then plan, then apply on `main`.
- Secrets are not used for AWS access: the workflow assumes an IAM role through
  the GitHub OIDC provider, with short-lived credentials per job
  (`AWS_ROLE_ARN_DEV`, `AWS_ROLE_ARN_PROD`).
- Before plan and apply, the prod and monitoring pipelines select their
  Terraform workspace and fail if it does not exist, so a pipeline can never
  plan against the other stack's state.
- Images are built outside Terraform (linux/arm64, pushed to ECR); Terraform
  only references the tags.

### Cross-account path

- Today there is none. The dev account is neither scraped nor peered; the only
  cross-account relationship is the human with credentials in both accounts.
- Planned: VPC peering between the dev VPC and the prod VPC plus a cross-account
  scrape role, so the monitoring stack can reach dev endpoints from the prod
  side (~$0.01/GB, no hourly peering charge). Drawn dashed.

## Node inventory

Costs are the list-price monthly figures given in the inventory; "—" means the
component has no separate line (free at this volume, or included in another
line).

### Internet and prod account — `architecture.mmd`

| Node | Service | Key configuration | Cost |
| --- | --- | --- | ---: |
| Route53 | DNS | 2 hosted zones (`nomaos.com`, `agrovesto`), authoritative for dev too | — |
| ACM | Certificates | wildcard `*.nomaos.com`, DNS-validated | — |
| Amplify | Front ends | 2 React apps, branch + domain per app | — |
| Internet Gateway | Networking | 1 in prod, 1 in dev | — |
| NAT gateway | Networking | 1 shared, single AZ, daily bill = hourly + 50 GB processed | ≈ $37 |
| ALB | Load balancing | internet-facing, 443 + 80 redirect, access logs to S3, 2 target groups, 2 rules | ≈ $35 |
| ECS cluster `main` | Compute | Fargate, ARM64; 5 API services, 256 vCPU / 512 MiB, desired 1, autoscaling 1→4 at 1000 req/task | ≈ $49 for the five API tasks |
| wallet / onboarding / input / moneval / serviceprovider | Services | ports 5001–5005, ECS Exec enabled, placeholder images today | included above |
| Vault service | Secrets | Fargate task, EFS raft storage, KMS key; not initialised | — |
| ECS cluster `monitoring` | Compute | 5 services at 512 vCPU / 1024 MiB, open-source images, pinned versions | ≈ $81 |
| prometheus / loki / tempo / grafana | Observability | 15-day metrics, 30-day logs, 14-day traces, dashboards | included above |
| edge task | Observability | 4 containers: alloy, alertmanager, blackbox, pushgateway | included above |
| EFS One Zone | Storage | one file system, per-component access points, 30-day IA lifecycle | ≈ $25 with logs and buckets |
| EFS multi-AZ | Storage | Vault raft storage | included above |
| RDS SQL Server Express | Database | db.t3.micro, 20 GB gp3 (50 GB ceiling), single AZ, 30-day backups, 5 databases | ≈ $20 |
| Secrets Manager | Secrets | 1 secret, master credentials, read at task start | — |
| KMS | Encryption | 2 keys (vault, monitoring) | — |
| S3 `alb_logs` | Storage | access logs, lifecycle expiry | — |
| CloudWatch Logs | Logs | 5 log groups, 30-day retention | ≈ $25 with EFS and buckets |
| Cloud Map | Discovery | private namespace `monitoring.internal`, 5 registrations, 4 CNAME aliases | ≈ $0.60 |
| SSM Parameter Store | Config | Grafana admin password as SecureString | — |
| ECR | Images | 5 prod repos, IMMUTABLE, 5 tags kept | — |

### Dev account — `architecture.mmd`

| Node | Service | Key configuration | Cost |
| --- | --- | --- | ---: |
| EC2 t3.medium | Compute | 2 vCPU / 4 GiB, docker compose host, EIP, SSM only (no SSH, no bastion) | ≈ $11.86 of the ≈ $29 |
| EBS | Storage | 50 GB root + 50 GB data, gp3 | ≈ $8.80 of the ≈ $29 |
| nginx + 5 API containers | Runtime | reverse proxy on 443 → containers on 5001–5005 | — |
| SQL Server container | Database | 5 databases on the data volume | — |
| Vault container | Secrets | dev secrets | — |
| EventBridge Scheduler | Scheduling | start 08:00, stop 20:00, Mon–Fri, Africa/Lagos (≈ 260 h/month) | — |
| ECR | Images | 5 dev repos, MUTABLE tags, 3 kept | — |
| Amplify | Front ends | 2 apps, 2 branches, domains | — |
| S3 bucket | Storage | SQL dumps, versioned, 14-day expiry | — |

### Telemetry and cost — `telemetry.mmd`

| Node | Service | Key configuration | Cost |
| --- | --- | --- | ---: |
| collector task | Batch | `rate(2 minutes)`, 0.25 vCPU / 0.5 GB, ECS API polling | ≈ $3.06 for all four scheduled tasks |
| mssql-metrics task | Batch | hourly, DMV query through Secrets Manager | included above |
| budget task | Batch | daily 06:15 UTC, DuckDB over CUR Parquet | included above |
| report task | Batch | monthly, fpdf2 PDF, SES send | included above |
| CUR | Billing data | daily Parquet, us-east-1, overwritten in place | — |
| SES | Mail | verified domain + DKIM, sandbox | — |
| pushgateway, prometheus, grafana, alertmanager | Observability | 9091 → 9090 → 3000; alert at 80 % of $250 | included in the monitoring ≈ $81 |

### Pipelines and state — `cicd.mmd`

| Node | Service | Key configuration | Cost |
| --- | --- | --- | ---: |
| dev.yml / prod.yml / monitoring.yml | CI | 1 pipeline per folder, fmt → security → tests → coverage 95 % → Sonar → Infracost → plan → apply | — |
| GitHub OIDC provider | Identity | 1 provider in the prod account, roles assumed per pipeline | — |
| prod state object | State | `s3://nomaos-tfstate-221434544570-eu-west-1/prod/bootstrap.tfstate`, shared by prod (workspace `prod`) and monitoring (workspace `monitoring`) | — |
| dev state object | State | `s3://nomaos-tfstate-353833416626-eu-west-1/dev/bootstrap.tfstate` | — |
| bootstrap root | State | local state file, creates both buckets, the OIDC provider and the roles | — |

Costs Infracost cannot describe, kept in a separate ledger and added to the
total: scheduled Fargate tasks ≈ $3.06, Cloud Map ≈ $0.60, in-use public IPv4
≈ $10.95 (dev Elastic IP, NAT gateway, ALB), internet egress ≈ $4.50.

## Boundaries and trust

**Accounts.** Two: prod `221434544570` carries the application, the monitoring
stack, the state objects for both prod and monitoring, the OIDC provider, the
CUR and SES; dev `353833416626` carries the dev application and its state
bucket. The only cross-account link today is a person holding credentials in
both. A cross-account scrape is planned, not deployed.

**Regions.** eu-west-1 for everything except the CUR bucket, which must live in
us-east-1.

**VPCs and tiers.** Prod has three tiers: public (Internet Gateway, NAT gateway,
ALB), private (ECS tasks, EFS mount targets, no inbound from the internet) and
database (RDS only, reached from the private tier). Dev has one public tier and
no private subnet, so every dev instance is directly addressable.

**Security-group intent.** Prod: `alb` is the only internet-facing group; `ecs`
accepts application traffic from `alb` and monitoring traffic from the
monitoring groups; `rds` accepts TDS 1433 from `ecs` only; `efs` accepts NFS
2049 from the monitoring and vault tasks. Grafana is reachable only from inside
the VPC. Dev: one group on the host, plus a locked-down default group — the
host is protected by nginx and the security group, not by a private subnet.

**Trust boundaries crossed at runtime.** Internet → ALB (mutually authenticated
by TLS, wildcard certificate). Tasks → AWS APIs over TLS with IAM roles, no
static keys anywhere: Secrets Manager, SSM, ECS, S3, SES, KMS. CI → AWS over
OIDC, short-lived credentials. Report mail leaves the account through SES to an
external mailbox.

**Data boundaries.** Monitoring state never leaves the VPC: EFS is private and
the Prometheus, Loki and Tempo endpoints are only resolvable through Cloud Map.
The CUR bucket and the config bucket are private, versioned where it matters,
and served to tasks through IAM roles.

## Assumptions

- Figures marked ≈ are the list-price monthly figures from the inventory and
  were not recomputed.
- The five API tasks are counted as one line (≈ $49); the per-service split is
  not given.
- "In-use public IPv4" assumes three addresses: the dev Elastic IP, the NAT
  gateway and the ALB.
- The edge task carries four containers but is drawn as one node, because it is
  one ECS task definition and one service; its containers are listed in the
  label. The same applies to the dev docker-compose host, which is drawn as one
  instance plus four container nodes.
- Amplify, the EventBridge scheduler and the dev S3 bucket have no separate
  cost line at the volumes described; they are drawn but costed as "—".
- The Alertmanager receivers are empty, so the alert path terminates inside the
  stack; the diagram shows the receiver node in the planned style.
- Wording follows the inventory: "not initialised" for Vault, "placeholder
  images" for the prod services, "sandbox" for SES.
