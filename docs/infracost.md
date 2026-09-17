# Costing the whole repo locally

Every stack in this repository is covered by one Infracost config, so a single
command prices dev, prod, monitoring and the bootstrap stack together:

```bash
./scripts/infracost.sh
```

It reads `infracost.yml`, writes the raw JSON to `.infracost/breakdown.json`,
print's Infracost's own table and then adds the costs Infracost cannot see
(`infracost-extras.json`) to give one combined monthly figure.

## What the config covers

| Project | Path | Account | What it is |
| --- | --- | --- | --- |
| bootstrap | `bootstrap/` | prod `221434544570` | state bucket, lifecycle rules, GitHub OIDC deploy role |
| dev | `dev/` | dev `353833416626` | EC2 app host, EBS disks, Elastic IP, 2 Amplify apps, 5 ECR repos, backup bucket |
| prod app | `prod/` | prod `221434544570` | 5 API Fargate services + Vault, RDS SQL Server Express, ALB, NAT gateway, ECR, EFS, log groups, flow logs, 2 Route53 zones |
| monitoring | `monitoring/` | prod `221434544570` | Prometheus, Loki, Tempo, Grafana, the `edge` task (Alloy + Alertmanager + blackbox + Pushgateway), 4 scheduled tasks, 2 buckets, EFS, Cloud Map |

The monitoring stack is in the prod account and shares prod's Terraform state
bucket (separate workspace), but it is its own Terraform root, so it is its own
project here: its lines can be reviewed — and removed — independently.

## Running it

```bash
brew install infracost                                # macOS
export INFRACOST_API_KEY=ico-...                      # free key: dashboard.infracost.io
./scripts/infracost.sh
```

No AWS credentials are needed. Infracost reads the HCL and AWS's public price
list; it never calls AWS and never runs `terraform`.

The equivalent raw commands, if you want to use the CLI directly:

```bash
infracost breakdown --config-file infracost.yml --show-skipped          # table
infracost breakdown --config-file infracost.yml --format json --out-file /tmp/cost.json
infracost output --path /tmp/cost.json --format html --out-file /tmp/cost.html
```

To diff a branch locally, break down both sides and compare:

```bash
infracost breakdown --config-file infracost.yml --format json --out-file /tmp/head.json
git stash && infracost breakdown --config-file infracost.yml --format json --out-file /tmp/base.json && git stash pop
infracost diff --path /tmp/head.json --compare-to /tmp/base.json
```

`.auto.tfvars` files are loaded automatically, exactly as Terraform loads them,
so the config only carries variables that have no value anywhere in the repo:

* `dev` — `mssql_sa_password`, the one secret with no committed value (a
  placeholder keeps the HCL parseable; nothing is deployed by a cost run).
* `monitoring` — `use_fargate_spot` pinned to `false` on purpose. See below.

## Usage assumptions

Infracost prices provisioned size automatically (instance classes, task CPU and
memory, storage size, ALB hours, NAT hours). Charges that depend on *usage* come
from `infracost-usage/<project>.yml`; the important ones:

| Assumption | Value | Where |
| --- | --- | --- |
| dev host runs 08:00–20:00 Mon–Fri, not 24/7 | `monthly_hrs: 260` | `infracost-usage/dev.yml` |
| dev disks | 50 GB root + 50 GB gp3 data | `dev.yml` (root from the instance block) |
| dev storage and images | ~3 GB of backups, 5 × 200 MB ECR repos | `dev.yml` |
| prod traffic | ~50 GB/month egress and NAT, ~2 LCU-hours on the ALB | `infracost-usage/prod.yml` |
| prod logs | 3 GB/month ingested (5 services, Vault, flow logs), 30-day retention | `prod.yml` |
| prod DNS | ~20k queries per record | `prod.yml` |
| monitoring EFS | 25 GB, deliberately all in Standard | `infracost-usage/monitoring.yml` |
| monitoring logs | ~1 GB/month ingested | `monitoring.yml` |

Change a number in those files and every figure moves with it. Each file has a
comment explaining where its value came from. A `resource_type_default_usage`
block at the top of each file is the safety net: any new bucket, repo, log group
or instance added later still gets a sane value instead of the $5 placeholder
that Infracost would otherwise apply.

## What Infracost cannot price

Infracost only prices resources in its price list, so five real costs in this
stack are invisible to it. `infracost-extras.json` itemises them and
`scripts/infracost.sh` adds them to the total:

| Item | Monthly |
| --- | ---: |
| monitoring Fargate batch tasks (collector, SQL Server metrics, CUR budget, monthly report) | $3.08 |
| monitoring Cloud Map private namespace + lookups | $0.60 |
| in-use public IPv4 addresses (dev Elastic IP, NAT gateway, ALB) | $10.95 |
| prod internet egress (~50 GB) | $4.50 |
| Amplify (2 dev apps), SES, EventBridge rules and Scheduler, CUR definition, KMS requests | $0.00 (free tier at this volume) |
| **Extras subtotal** | **$19.13** |

Why each one is missing:

* **Scheduled ECS tasks** — they are `aws_ecs_task_definition`s that EventBridge
  starts, not `aws_ecs_service`s, and Infracost prices Fargate through the
  service. The collector alone is ~$3/month because it runs every two minutes.
* **Cloud Map** — `aws_service_discovery_*` has no pricing entry. AWS bills the
  private hosted zone at $0.50/month; ECS service-discovery registrations are
  free, only lookups and DNS queries cost extra.
* **Public IPv4** — Infracost's `aws_eip` only charges the idle-address usage
  type, so an attached Elastic IP, a NAT gateway's address and an ALB's address
  all read as free. AWS has charged every in-use public IPv4 since 2024.
* **Egress** — data transfer out is metered against the account, not against a
  Terraform resource, so there is nothing for Infracost to attach it to.
* **Amplify, SES, EventBridge Scheduler, CUR** — not in the price list at all;
  all currently inside their free tiers, which is why they are $0 rather than
  dropped.

## Things to know before you trust a number

* **Fargate Spot** — the monitoring services use
  `launch_type = var.use_fargate_spot ? null : "FARGATE"`. Infracost only prices
  a service whose `launch_type` is `FARGATE`, so with the flag on, the four
  always-on tasks plus the edge task (~$81/month) would vanish from the report
  instead of showing a discount. The config pins the flag to `false` and the
  estimate stays at on-demand prices; spot is worth roughly $16/month.
* **Autoscaling** — prod services scale from 1 to 4 tasks on load. Infracost
  prices `desired_count`, so the report shows the steady state (1 task each).
* **Infracost's own defaults** — without a usage file, unset usage keys fall back
  to Infracost's predefined values ($5/month per resource type). That is why the
  usage files exist: they make the small resources small.
* **CI and local can differ** — the three pipelines currently run
  `infracost breakdown --path base/<dir>` per folder for their PR comment. The
  config file is the local, repo-wide view; pointing CI at
  `--config-file infracost.yml --project-name <name>` would make the two
  identical.
* **One-off and unpriced-by-design** — AWS Support, domain registration, tax and
  the first image pushes are out of scope. So is anything without a price list
  entry that is not in `infracost-extras.json`: if you add a resource type that
  Infracost skips, add a line there, or the report will quietly understate it.

## Expected shape of a clean run

With the stack as committed (monitoring after the edge consolidation), a full
run should look roughly like this — treat it as a sanity check, not a target:

| Project | Expected |
| --- | ---: |
| bootstrap | ~$0.10–0.20 |
| dev | ~$21 (plus $3.65 of IPv4 in extras) |
| prod app | ~$140–150 (plus $7.30 of IPv4 and $4.50 of egress) |
| monitoring | ~$85–90 (plus ~$3.70 of batch tasks and Cloud Map) |
| **Combined** | **~$270** |

The narrative estimate in the root `README.md` and the earlier model land at
~$290 for the pre-consolidation stack; the difference is the ~$16/month the edge
task saves and Amplify sitting inside its free tier.
