# Architecture-diagram prompt

Paste the whole fenced block below into any capable AI tool (Claude, ChatGPT,
Gemini…). It is self-contained: the inventory is the ground truth, so the model
does not need access to this repository.

Suggested use:

1. Ask for the Mermaid diagram first, render it at <https://mermaid.live>, and
   iterate on layout there.
2. For a presentation-quality picture, feed the *same* inventory plus the style
   line (bottom of this file) to an image or diagram tool, and keep the Mermaid
   as the source of truth — generated pictures drift from reality.
3. `draw.io` (Extras → Edit Diagram → paste Mermaid) and Excalidraw+ can both
   import the Mermaid output if you want to hand-edit boxes.

---

```
ROLE
You are a senior AWS solutions architect who produces diagram-as-code. I am
handing you the complete inventory of a two-account AWS estate. Produce an
architecture diagram and the documents that go with it. Use ONLY what is in the
inventory: do not invent resources, regions, tools or data flows, and do not
"improve" the design. If something is ambiguous, list it under Assumptions
instead of guessing.

DELIVERABLES (output in this order)

1. architecture.mmd — a Mermaid `flowchart LR`, valid and renderable as-is.
   Use subgraphs for boundaries: the internet/DNS edge, then one subgraph per
   AWS account, then per VPC, then per subnet tier, then compute clusters.
   Use `direction TB` inside subgraphs so nesting stays readable.
   Add classDef styles: internet (grey), aws-managed (amber), compute (blue),
   data (green), observability (purple), ci-cd (teal), planned (dashed border).
   Keep it under ~70 nodes; if it does not fit legibly on one page, split it
   into three diagrams (runtime/request path, telemetry + cost data flow,
   CI/CD + state) and say which one is which.

2. narrative.md — markdown with:
   • a walkthrough of every data path, one bullet per hop, naming protocols,
     ports and schedules: user request path, log path, metric path, trace path,
     alert path, cost path, CI/CD path, cross-account path;
   • a table of every node from the diagram: name, service, key configuration
     (size/SKU, retention, count), and monthly cost where the inventory gives
     one;
   • a "boundaries and trust" section: accounts, VPCs, subnets, security-group
     intent, which paths cross an account boundary;
   • an "Assumptions" section.

3. review.md — exactly 10 findings in priority order, each with: what is
   fragile or single-point-of-failure, blast radius, and the smallest concrete
   change that fixes it. Then a short "planned work" list drawn from the
   inventory's dashed items.

DIAGRAM RULES
- Solid arrow = exists today. Dashed arrow = planned/disabled (listed as such).
- Label every arrow with what flows and how: e.g. `HTTPS 443 → 5001`,
  `OTLP 4317`, `rate(2 min)`, `cron(0 8 1 * ? *)`, `S3 PutObject (Parquet)`.
- Distinguish runtime traffic from control-plane/API calls: the scheduled jobs
  call AWS APIs (ECS DescribeTasks, RDS DMVs through the master secret) — show
  that as HTTP/API, not as an in-VPC database connection.
- Show the shared Terraform state object and the workspace separation; it is a
  real part of the architecture.
- Do not draw a component that the inventory does not list. Do not merge two
  distinct components into one box.

GROUND TRUTH INVENTORY

=== GLOBAL ===
- Two AWS accounts, one region each for resources: prod 221434544570 (eu-west-1,
  and us-east-1 only for the Cost and Usage Report bucket), dev 353833416626
  (eu-west-1).
- IaC: Terraform >= 1.7 (CI pins 1.10.5), four independent roots: bootstrap,
  dev, prod, monitoring. No modules; each root is standalone.
- State: prod and monitoring SHARE one state object
  s3://nomaos-tfstate-221434544570-eu-west-1/prod/bootstrap.tfstate, separated
  by Terraform workspaces `prod` and `monitoring`; dev uses
  s3://nomaos-tfstate-353833416626-eu-west-1/dev/bootstrap.tfstate; bootstrap
  keeps LOCAL state and creates the buckets, the GitHub OIDC provider and the
  deploy roles.
- Region-level facts: one shared NAT gateway in prod, single-AZ by flag;
  RDS single-AZ by flag; three public IPv4 addresses billed (dev Elastic IP,
  NAT gateway, ALB).

=== PROD ACCOUNT (221434544570), root `prod` — the application ===
Network
- VPC agrovesto-prod-vpc; three subnets: public, private, database; Internet
  Gateway; one NAT gateway (with Elastic IP) in the public subnet; route tables
  public→IGW, private→NAT, database associated to the private route table; VPC
  flow logs to a CloudWatch log group (30-day retention).
- Security groups: alb (internet-facing), ecs, rds (accepts only from ecs), efs.
Compute
- Application Load Balancer agrovesto-prod-alb (internet-facing, access logs to
  S3 bucket alb_logs, HTTP:80 → HTTPS:443 redirect, HTTPS listener with a
  wildcard ACM certificate for *.nomaos.com), two target groups: `services`
  (the five APIs) and `vault`; two listener rules doing the host/path routing.
- ECS cluster `main`, Fargate, Graviton/ARM64. Five API services — wallet
  (5001), onboarding (5002), input (5003), moneval (5004), serviceprovider
  (5005) — each 256 vCPU/512 MiB, desired count 1, Application Autoscaling
  1 → 4 tasks at 1000 requests per task, ECS Exec enabled.
- Vault service on Fargate (secrets store, not yet initialized) with its own
  task role, an EFS file system (multi-AZ) for raft storage and a KMS key.
- Two one-off/scheduled task definitions: db_init (runs once through a
  null_resource → ECS RunTask when enabled) and db_size_check (EventBridge
  schedule, currently DISABLED).
- Images: ECR repos agrovesto-prod-<svc> ×5, IMMUTABLE tags, 5 kept.
  Services currently run a placeholder image; real ASP.NET images are built
  elsewhere (linux/arm64) and pushed here.
Data
- RDS SQL Server Express, db.t3.micro, 20 GB gp3 (max 50), single-AZ, 30-day
  backups, in the database subnet behind the rds security group; five
  databases: wallet, onboarding, input, moneval, serviceprovider; master
  credentials are a generated password stored in Secrets Manager secret
  agrovesto-prod-mssql-master (services read it at task start).
- EFS file system for Vault (multi-AZ) + access point + mount targets.
- Secrets Manager, KMS key alias/vault, SSM.
DNS and certificates
- Route53 hosted zone nomaos.com (authoritative for everything, including the
  dev hostnames) plus a second zone (agrovesto); alias/A records for the five
  APIs, vault and grafana; the ACM wildcard validation records.
Native (non-monitoring) alerts, currently OFF
- CloudWatch metric filter + metric alarm + SNS topic with an e-mail
  subscription for the SQL Server 10 GB Express limit — db_size_alarm_enabled
  is false, so this path exists in code but is not deployed. The equivalent
  signal is produced by the monitoring stack instead.

=== PROD ACCOUNT, root `monitoring` — the observability stack ===
- Lives in the same account and VPC as the app, but is its own root, its own
  workspace and its own cost line. Open-source only: no CloudWatch alarms,
  dashboards, metric filters, X-Ray or Container Insights anywhere.
- ECS cluster `monitoring`, four always-on Fargate services at 512 vCPU/1024 MiB
  (open-source images, pinned versions):
  • prometheus 9090 (15-day metric retention)
  • loki 3100 (30-day logs)
  • tempo 3200, OTLP 4317/4318 (14-day traces)
  • grafana 3000 (dashboards, datasource and alert provisioning)
  and one `edge` task that carries FOUR containers: alloy 3100/4317/4318/12345
  (OTLP + Loki ingest gateway), alertmanager 9093 (routing), blackbox-exporter
  9115 (uptime/TLS probes), pushgateway 9091 (batch-job metrics).
- One shared One Zone EFS file system with per-component access points
  (Prometheus TSDB, Loki chunks, Tempo blocks, Grafana SQLite, Alloy,
  Alertmanager, blackbox), 30-day infrequent-access lifecycle; one KMS key.
- Cloud Map private namespace monitoring.internal with five registrations
  (prometheus, loki, tempo, grafana, edge) and four Route53 CNAME aliases so
  the old names alloy / alertmanager / blackbox / pushgateway resolve to the
  edge task. Containers also get their config from S3 through an init container
  that syncs s3://<config bucket>/config onto the shared volume.
- Scheduled Fargate tasks (EventBridge rules → ECS RunTask):
  • collector — rate(2 minutes): calls the ECS API for task/service metrics and
    publishes them to pushgateway
  • mssql-metrics — hourly: reads an RDS DMV through the master secret in
    Secrets Manager and publishes mssql_database_size_bytes (and the 8 GiB
    warning threshold used by an Alertmanager rule), no CloudWatch involved
  • budget — daily cron(15 6 * * ? *): DuckDB budget job over the CUR data
  • report — monthly cron(0 8 1 * ? *): renders the cost/usage PDF
- Cost pipeline: AWS Cost and Usage Report (daily, Parquet, into a us-east-1 S3
  bucket in this account) → S3 → DuckDB task → pushgateway → Prometheus →
  Grafana budget dashboard, alert at 80 % of a $250 monthly budget; the monthly
  job mails a PDF (fpdf2) through SES, whose domain identity and DKIM records
  are managed in Route53 by Terraform. SES starts in the sandbox.
- Grafana and the prod ALB: a target group and listener rule on the PROD load
  balancer publish grafana.nomaos.com; grafana_allowed_cidrs is empty, so it is
  reachable from inside the VPC only.
- Telemetry inputs: blackbox probes HTTPS every 15 s for the seven prod
  endpoints (the five APIs, vault health, grafana health); applications push
  logs/traces/metrics to Alloy; alert rules cover ECS task/service state and the
  RDS size signal; alertmanager receivers are configured but currently empty
  (no e-mail, no webhook), so alerts stay inside the stack.
- State, IAM: task roles for the collector, the metrics job and the report;
  Grafana's admin password is generated and stored as an SSM SecureString.

=== DEV ACCOUNT (353833416626), root `dev` — the application ===
- VPC with a single public subnet, Internet Gateway, route table, one security
  group; default security group locked down.
- EC2 t3.large (2 vCPU / 8 GiB) with an Elastic IP, a 50 GB gp3 root volume, a
  50 GB gp3 data volume for SQL Server and a 20 GB gp3 volume for the log
  stores, instance profile with SSM Session Manager access plus SSH from
  `allowed_ssh_cidrs` (no bastion, no load balancer).
- Docker Compose stack on that host: nginx 1.27-alpine reverse proxy in front of
  five ASP.NET API containers (wallet 5001, onboarding 5002, input 5003, moneval
  5004, serviceprovider 5005 — placeholder images today), a SQL Server
  container holding the five databases (wallet, onboarding, input, moneval,
  serviceprovider), a Vault container, and the on-host logging and metrics stack
  — Alloy tailing the docker logs and journald into Loki, Grafana, Prometheus
  with cAdvisor and node-exporter. Same compose project, no CloudWatch Logs or
  Container Insights anywhere in dev. Grafana is the only one of them nginx
  serves publicly (`dev-logs`, IP-allowlisted); the rest bind 127.0.0.1.
- EventBridge Scheduler keeps cost down: start 08:00, stop 20:00, Monday to
  Friday, Africa/Lagos — roughly 260 running hours a month.
- ECR repos agrovesto-dev-<svc> ×5 (MUTABLE tags, 3 kept); Amplify hosts two
  React front ends (nomaos-landingpage and onboarding-frontend, branch `dev`)
  with branch and domain association; one versioned S3 bucket for SQL Server
  dumps with a 14-day expiry.
- No DNS of its own: manage_dns is false, so the prod zone publishes
  wallet.dev.nomaos.com and friends. No observability wiring at all yet.

=== CI/CD ===
- Three GitHub Actions pipelines, each triggered only by edits inside its own
  folder: dev → dev/**, prod → prod/**, monitoring → monitoring/**. Stages:
  `terraform fmt -check -recursive`, checkov + trivy (security), terraform test
  with a 95 % resource-coverage gate (mock providers, no AWS credentials), a
  SonarQube scan per folder, an Infracost cost comment on the pull request,
  then plan, then apply on main. AWS access is OIDC role assumption
  (AWS_ROLE_ARN_DEV / AWS_ROLE_ARN_PROD), never static keys; the prod and
  monitoring pipelines assert the correct Terraform workspace before planning.
- The bootstrap root creates the state buckets, the GitHub OIDC provider and the
  deploy roles that those pipelines assume.

=== PLANNED / DISABLED (draw dashed) ===
- Dev observability: VPC peering to the prod VPC plus a cross-account scrape
  role so the monitoring stack can scrape dev (~$0.01/GB, no hourly charge).
- Native RDS size alarm path in prod (metric filter + alarm + SNS) — disabled.
- ECS autoscaling beyond 1 task, multi-AZ RDS and a NAT gateway per AZ — behind
  flags, off for cost.
- Vault is provisioned but not initialized; application secrets still come from
  Secrets Manager.
- Real API images (currently placeholders) and the Alertmanager receivers
  (currently empty).
- Dev DNS records typed manually into the prod zone.

=== COST CONTEXT (monthly, eu-west-1 list price) ===
dev ≈ $29; prod application ≈ $154; monitoring ≈ $107 counted under prod;
estate ≈ $290. Biggest lines: ALB ≈ $35, NAT gateway ≈ $37 including 50 GB,
RDS ≈ $20, five Fargate APIs ≈ $49 (6 × 256/512), the five monitoring Fargate
services ≈ $81, EFS + storage + logs ≈ $25. Costs Infracost cannot price —
scheduled Fargate tasks ≈ $3.06, Cloud Map ≈ $0.60, in-use public IPv4 ≈ $10.95,
internet egress ≈ $4.50 — are kept in a separate ledger and added to the total.
Do not recompute these; quote them as given and mark them as list price.

STYLE
- Neutral, factual, no marketing language.
- British spelling, sentence case, no emoji, no exclamation marks.
- Node labels: short name + the one number that matters (port, size, count).
  Everything else goes in the tables.
- Do not use the word "leverage".

SELF-CHECK BEFORE ANSWERING
- Every node appears in the inventory, and every inventory resource that can
  carry traffic or state appears in the diagram.
- Every arrow has a direction and a label; no arrow points to a box that cannot
  receive that traffic.
- Dashed styling is used only for the planned/disabled list.
- The three deliverables are self-consistent: same names, same ports.
```

## Style line for an image generator

If you want a picture rather than a diagram, give the image tool the inventory
above plus:

```
Clean AWS architecture poster, flat vector style, white background, thin
2px borders, subtle drop shadows, rounded rectangles grouped in labelled zones
(Internet / prod account VPC / prod monitoring / dev account / CI-CD), colour
per layer — compute blue, data green, observability purple, CI teal, planned
elements dashed — arrows with small protocol labels such as HTTPS 443, OTLP
4317, rate(2 min). Professional, minimal, no photographic elements, no clip
art, no 3D, legible at 100 % zoom. Portrait orientation, 4:5.
```
