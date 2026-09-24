# Review

Ten findings, highest blast radius first. Each one states what breaks, how far
it spreads, and the smallest change that fixes it. Nothing here is drawn from
outside the inventory.

## 1. RDS SQL Server Express, single-AZ — the whole application stops with it

**Fragile:** one `db.t3.micro` instance with 1 GiB of RAM, a 10 GB per-database
cap (Express limit), no SQL Server Agent and no Multi-AZ *available* on the
Express edition. Every API in the estate reads and writes it.
**Blast radius:** all five prod services fail at once. A database crossing 8 GB
starts failing writes while the monitoring alert only warns at that point; at
10 GB writes fail outright.
**Smallest fix:** run the documented upgrade path — snapshot, restore as
`sqlserver-web` or `sqlserver-se` on `db.m7i.large`, keep the endpoint name —
and only then set `mssql_multi_az = true`. Until then, treat 8 GB as the real
ceiling and add the size signal to whatever pages a human.

## 2. One NAT gateway, one AZ — private egress is a single point of failure

**Fragile:** `single_nat_gateway = true` puts every private-subnet and
database-subnet egress path through one gateway in one AZ.
**Blast radius:** if that AZ degrades, task image pulls fail, Secrets Manager
calls fail, SES and CUR traffic from the budget and report tasks fail, and RDS
in the database subnet loses its outbound patching path. Existing connections to
the ALB survive; everything that needs outbound dies.
**Smallest fix:** `single_nat_gateway = false` and apply — one gateway per AZ,
≈ $35/month more.

## 3. Alerts have no destination

**Fragile:** alert rules exist and Alertmanager evaluates them, but
`alert_email`, `alert_smtp_host` and `alertmanager_webhook_url` are all empty.
The native CloudWatch path that could have paged someone is disabled
(`db_size_alarm_enabled = false`).
**Blast radius:** every alert in the estate is silent. A failed task, a service
with no healthy targets, a database at 9 GB — all of it is only visible to
someone already looking at Grafana.
**Smallest fix:** fill `alert_email` (or the webhook URL) in the monitoring
tfvars and apply; one variable, no new components.

## 4. All monitoring state lives on one One Zone EFS file system

**Fragile:** Prometheus TSDB, Loki chunks, Tempo blocks, Grafana's SQLite
database and Alertmanager's notification state all sit on a single One Zone EFS
file system; a zone failure takes the file system with it, and there is no
backup resource in the inventory.
**Blast radius:** up to 15 days of metrics, 30 days of logs and 14 days of
traces are unrecoverable; dashboards and silences are lost with Grafana's
SQLite file. The application keeps running, but the estate goes blind exactly
when the signal matters most.
**Smallest fix:** keep the file system where it is and add an AWS Backup plan
(or EFS automatic backup) for it. If the AZ exposure itself matters more than
the ~$16/month, move EFS to regional.

## 5. One Fargate task per API — no headroom during changes

**Fragile:** every API service runs `desired_count = 1`, with autoscaling from 1
to 4 on request load. A rolling deployment, a task replacement or a host-level
Fargate event takes the only task away.
**Blast radius:** the affected endpoint answers 503 from the ALB until the
replacement task is healthy; with all five services deploying together, a bad
release can touch all of them.
**Smallest fix:** raise `desired_count` to 2 for the services that matter most
(≈ $8/month each at 256/512) and deploy with the ECS default rolling update so
one task is always healthy.

## 6. Prod runs placeholder images

**Fragile:** the five prod services still reference a placeholder image that
serves HTTP on `$PORT`, not the real application. ECR repos exist with
IMMUTABLE tags but nothing points at them.
**Blast radius:** the ALB health checks pass and the stack looks healthy while
serving no product capability — the failure is silent and only visible as wrong
responses. It also blocks any meaningful latency or error-rate alerting.
**Smallest fix:** build each API for `linux/arm64`, push to
`agrovesto-prod-<svc>` with a release tag, and set the `image` values to the
immutable digests; an amd64-only image dies immediately with `exec format
error`.

## 7. SES is still in the sandbox

**Fragile:** the monthly report is delivered through SES with a
Terraform-managed domain identity and DKIM, but the account has not been moved
out of the sandbox.
**Blast radius:** the report only reaches verified addresses. If the recipient
list is anything but those addresses, the monthly PDF is silently undelivered —
and the same applies to Alertmanager e-mail if it is switched on.
**Smallest fix:** request SES production access for the sending domain before
filling `report_recipients`, and send the first report to a verified address to
prove the path.

## 8. Vault is deployed but not initialised

**Fragile:** a Vault service runs as its own Fargate task with EFS storage and a
KMS key, but it has never been initialised and applications still read secrets
from Secrets Manager.
**Blast radius:** nothing depends on it, so nothing breaks — but it bills every
month, it looks like a secrets store in the diagram, and the day someone does
switch `vault_secrets_enabled = true` there is no tested initialisation,
unseal or backup procedure behind it.
**Smallest fix:** choose one. Either set `enable_vault = false` and re-apply,
or finish the bootstrap in `vault.tf` (init, unseal, kv seeding) and record the
recovery procedure before moving any secret into it.

## 9. Prod and monitoring share one state object, guarded only in CI

**Fragile:** both stacks write
`s3://nomaos-tfstate-221434544570-eu-west-1/prod/bootstrap.tfstate`, separated by
the `prod` and `monitoring` workspaces. CI asserts the workspace before plan and
apply; a workstation running `terraform apply` from the default workspace has no
such guard.
**Blast radius:** a plan or apply against the wrong workspace either proposes to
create everything (confusing but harmless) or, worse, operates on the other
stack's resources with its own configuration.
**Smallest fix:** keep the workspace split but make the object safe: either give
monitoring its own key, or add an S3 bucket policy that denies `s3:PutObject` to
the state prefix unless the request carries the expected workspace prefix
(workspace state lives under `env:/`). The first is a one-line backend change
plus a state move.

## 10. Bootstrap state is local, and dev has no telemetry

**Fragile:** two unrelated gaps with the same shape — the resource that makes
everything else reproducible keeps its state on one workstation, and the dev
account is not observed at all (`manage_dns = false`, no scrape, no log
shipping, no peering).
**Blast radius:** losing the laptop loses the ability to manage the state
buckets, the OIDC provider and the deploy roles without manual imports; dev
failures are found by developers, not by monitoring, and dev hostnames are
typed into the prod zone by hand, so they drift the moment an IP changes.
**Smallest fix:** two small steps — migrate bootstrap to a secured remote state
bucket with locking (or document and test a `terraform import` recovery), then
re-address one VPC before adding dev-to-prod peering with a cross-account scrape role so dev joins the same
Cloud Map based scraping (≈ $0.01/GB, no hourly charge).

## Planned work

Drawn dashed in the diagrams, listed here for completeness.

- **Dev observability:** Re-address an overlapping `172.96.0.0/16` VPC before peering dev and prod; add a cross-account
  scrape role; dev then appears in Prometheus like any other target.
- **Native SQL Server size alarm:** the prod metric filter, alarm and SNS topic
  exist but stay disabled while the open-source path covers the same signal.
- **Cost levers, currently off:** ECS autoscaling above 1 task, Multi-AZ RDS,
  one NAT gateway per AZ, and Fargate Spot for the monitoring services
  (`use_fargate_spot`, worth roughly $16/month at current sizes).
- **Images and receivers:** real ARM64 API images in place of the placeholders,
  and Alertmanager receivers filled in.
- **Dev DNS records:** currently typed into the prod zone from dev stack
  outputs; make that mechanical once the peering lands.
