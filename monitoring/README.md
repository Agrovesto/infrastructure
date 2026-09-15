# Monitoring stack (prod account)

Open-source observability for the Agrovesto prod stack: metrics, logs, traces,
dashboards, uptime probes, ECS cluster/service state, cost/budget reporting and
SQL Server (RDS) metrics — all running on ECS Fargate with no AWS-native
observability service in the loop.

Native tooling that this stack deliberately replaces: CloudWatch alarms, metric
filters and dashboards, Container Insights, X-Ray, Performance Insights, RDS
enhanced monitoring, AWS Budgets.

## Components

| Component | Image | Port | Purpose |
| --- | --- | --- | --- |
| Prometheus | `prom/prometheus` | 9090 | Metrics storage, recording/alert rules, scrape config |
| Alertmanager | `prom/alertmanager` | 9093 | Alert routing (email / webhook), grouping, silences |
| Loki | `grafana/loki` | 3100 | Log storage and query (TSDB filesystem, 30 days) |
| Tempo | `grafana/tempo` | 3200 / 4317 / 4318 | Trace storage, OTLP ingest and span metrics (metrics-generator, remote-written to Prometheus) |
| Grafana OSS | `grafana/grafana-oss` | 3000 | Dashboards, datasource provisioning, alert view |
| Alloy | `grafana/alloy` | 3100 / 4317 / 4318 / 12345 | Telemetry gateway: OTLP receiver, Loki push API, self-metrics |
| blackbox-exporter | `prom/blackbox-exporter` | 9115 | Synthetic uptime/TLS probes |
| Pushgateway | `prom/pushgateway` | 9091 | Landing point for the scheduled cost, SQL Server and ECS jobs |
| CUR + DuckDB job | `python:3.12-slim` | – | Daily cost aggregation from the Cost and Usage Report |
| SQL Server metrics job | `python:3.12-slim` | – | Hourly DMV queries against prod RDS, pushed to Pushgateway |
| ECS collector job | `python:3.12-slim` | – | Every two minutes: ECS cluster/service state to Pushgateway and prod task logs into Loki |

Every task is a Graviton (ARM64) Fargate task pinned to a single private subnet,
with one shared One Zone EFS file system (encrypted, Infrequent Access after 30
days) mounted through per-component access points. All state is on that file
system; every task has `enable_execute_command` on, so `aws ecs execute-command`
gives a shell without SSH.

## Cost

The whole stack is deliberately small: one availability zone, one Fargate task
per component, hourly/daily batch jobs instead of always-on exporters where
possible, and no NAT, no second load balancer, no managed observability service.

Rough monthly order of magnitude (eu-west-1 on-demand prices, ARM64):

| Item | Approx. |
| --- | --- |
| 7 always-on tasks (~0.25 vCPU / 0.5–1 GB each) | ~$55–70 |
| One Zone EFS, a few GB plus IA transition | ~$2 |
| KMS key (EFS + config bucket) | ~$1 |
| Prometheus 10 GB volume on EFS, 15 day retention | included above |
| Scheduled jobs (hourly SQL Server task ~30 s, daily CUR task) | <$1 |
| ECS collector task, every 2 minutes (~45 s per run, 0.25 vCPU / 0.5 GB) | ~$3 |
| CUR bucket storage (Parquet, 400 day lifecycle) | <$0.5 |
| Config bucket (a few KB) | ~$0 |
| **Total** | **~$65–80** |

Levers, in order of effect:

- `use_fargate_spot = true` moves Alloy, blackbox and Pushgateway (the tasks that
  can be interrupted) to Fargate Spot; Prometheus, Loki, Tempo, Grafana and
  Alertmanager stay on demand so WAL/TSDB writes are never cut short.
- `service_sizing` shrinks or grows each component independently.
- `metrics_retention` / `metrics_retention_size` cap Prometheus; `logs_retention_hours`
  and `traces_retention_hours` cap Loki and Tempo.
- `enable_cost_monitoring = false` and `enable_rds_monitoring = false` remove the
  scheduled jobs entirely.
- `enable_ecs_monitoring = false` drops the ECS collector, and
  `enable_ecs_log_shipping = false` keeps its metrics while it stops reading
  CloudWatch Logs (`collector_schedule_expression` also changes the cadence).

## Layout

```
monitoring/
├── versions.tf variables.tf terraform.auto.tfvars   root module and committed defaults
├── locals.tf        every rendered config file (Prometheus, Alertmanager, Loki, Tempo, Alloy, blackbox, Grafana provisioning, rules)
├── data.tf          discovery: prod VPC, private subnets, ALB, HTTPS listener, ALB SG, Route53 zone
├── cloudmap.tf      Cloud Map namespace monitoring.internal, ECS cluster, component log group
├── efs.tf kms.tf    shared state: One Zone EFS, mount target, access points, CMK
├── iam.tf           execution / task / EventBridge roles, scoped inline policies
├── security_groups.tf  internal, grafana and efs security groups
├── config.tf        config bucket + objects, delivered to the tasks by the init container
├── {prometheus,alertmanager,loki,tempo,grafana,alloy,exporters}.tf  task definitions and services
├── grafana.tf       ALB target group, listener rule, Route53 alias for grafana.<domain>
├── cost.tf          Cost and Usage Report bucket + report definition, daily budget task
├── rds.tf           scheduled SQL Server metrics task
├── collector.tf     scheduled ECS collector (cluster/service state, service logs)
├── dashboards/      platform.json services.json cost.json ecs.json (auto-provisioned)
├── scripts/         budget_report.py, mssql_metrics.py, ecs_metrics.py, ecs_logs.py
├── checkov.yml trivy.yml   scan configuration used by the monitoring pipeline
└── tests/           terraform test suites (mock_provider, no AWS calls)
```

## Configuration flow

Config is data, not images: `locals.tf` renders each component's file, `config.tf`
publishes them as objects in the CMK-encrypted config bucket
(`config/<component>/<path>`), and a small `aws-cli` init container syncs them onto
the EFS volume at `/config/<path>` before the component starts. S3 rather than SSM
parameter values because the dashboards and scripts are larger than the 4 KB
(standard) and 8 KB (advanced) Parameter Store limits; the generated Grafana admin
password stays an SSM `SecureString`. Changing a value therefore needs a redeploy:

```bash
aws ecs update-service --cluster agrovesto-monitoring \
  --service agrovesto-monitoring-prometheus --force-new-deployment
```

The Grafana admin password is generated by Terraform, stored as
`/agrovesto-monitoring/grafana/admin-password` and injected into the container as
`GF_SECURITY_ADMIN_PASSWORD`:

```bash
aws ssm get-parameter --name /agrovesto-monitoring/grafana/admin-password \
  --with-decryption --query Parameter.Value --output text
```

## Grafana access

Grafana is served by the **existing prod ALB** (`https://grafana.nomaos.com`): a
new target group plus a listener rule at priority `grafana_listener_rule_priority`
(900), matched by host header and — when set — `grafana_allowed_cidrs`. No extra
load balancer or certificate is created.

With `grafana_allowed_cidrs = []` the ALB only accepts Grafana traffic from inside
the VPC (the rule's source-IP condition is added for non-empty lists). To reach it
from a workstation, open a tunnel through a host in the VPC, or set the CIDR list
to your office/VPN ranges.

## Onboarding a service

1. **Logs** — nothing to do if the task keeps the `awslogs` driver: the ECS
   collector ships the prod log groups into Loki every two minutes (below). To
   drop CloudWatch out of the path, push to the Alloy gateway instead:
   - Loki push API: `http://alloy.monitoring.internal:3100/loki/api/v1/push`
   - OTLP logs: `http://alloy.monitoring.internal:4318/v1/logs`
   Label `service=<name>`; the services dashboard assumes `source="app"` plus a
   `service` label for the error-rate panels.
2. **Traces** — send OTLP to `alloy.monitoring.internal:4317` (gRPC) or `:4318`
   (HTTP). Tempo keeps 336 hours; the Grafana Loki datasource links `trace_id=...`
   to Tempo automatically. Tempo's metrics-generator turns those spans into
   `traces_spanmetrics_calls_total` / `traces_spanmetrics_latency_*` series, which it
   remote-writes into Prometheus (the "Spans by service" panel and the Tempo
   datasource's trace-to-metrics links read them there).
3. **Metrics** — expose a Prometheus endpoint on the task's port and add it to
   `local.prometheus_config`; the internal security group already allows 9090,
   3100, 3200, 4317-4318, 9091, 9093, 9115 and 12345 inside the VPC.
4. **Uptime** — add the public URL to `probe_targets` (blackbox probes HTTP 2xx,
   follows redirects and checks TLS expiry).

## Alerts

Rules live in four Prometheus files, all delivered with the rest of the config:

- `platform.yml` — uptime (`ProbeFailing`, `ProbeSlow`, `TlsCertificateExpiring`)
  and component health (`MonitoringTargetDown`).
- `cost.yml` — `BudgetThresholdExceeded` (projected month-end spend over
  `budget_alert_ratio` of `monthly_budget_usd`) and `CostReportStale`.
- `database.yml` — `MssqlUnreachable`, `MssqlMetricsStale`, `MssqlLowDiskSpace`,
  `MssqlBlockedSessions`, `MssqlDeadlockSpike`, `MssqlDatabaseNearSizeLimit`.
- `ecs.yml` — `EcsMetricsMissing`, `EcsCollectorFailing`, `EcsServiceShortOfTasks`,
  `EcsServiceTasksPending`, `EcsDeploymentFailed`, `EcsTasksStopping`,
  `EcsLogShipperStalled`.

`alert_email` + `alert_smtp_host` + `alert_smtp_user` (+ the
`TF_VAR_alert_smtp_password` secret) enable email delivery;
`alertmanager_webhook_url` adds a Slack/Mattermost-compatible webhook. With all of
them empty, alerts stay visible in Alertmanager and Grafana and nothing is sent
out.

## Cost and budget reporting

1. `aws_cur_report_definition.daily` asks the billing service for a daily Parquet
   report in `<project>-monitoring-cur-<account>` (us-east-1, the only region CUR
   supports), expiring after 400 days.
2. An EventBridge schedule (`budget_schedule_expression`, default 06:15 UTC) starts
   a Fargate task that pip-installs DuckDB, aggregates the month-to-date Parquet
   objects and pushes `cost_month_to_date_usd`, `cost_projected_month_usd`,
   `budget_month_usd`, `budget_utilization_ratio`, `cost_report_timestamp_seconds`
   and `cost_by_service_month_to_date_usd` to Pushgateway under `job="budget"`.
3. Prometheus scrapes Pushgateway (it is the only scraped target that is not a
   long-lived service) and the `cost.yml` rules raise the alerts.

The first data point needs one CUR delivery, so the panels stay empty for about a
day after the first apply.

## ECS services and cluster (no Container Insights)

One scheduled task (`agrovesto-monitoring-ecs-collector`, every two minutes by
default) does two jobs:

1. **Cluster and service state** — `ecs_metrics.py` reads the ECS API
   (`ListServices`/`DescribeServices`, `ListTasks`/`DescribeTasks`) and pushes
   `ecs_up`, `ecs_cluster_services`, `ecs_cluster_running_tasks`,
   `ecs_cluster_pending_tasks`, the per-service `ecs_service_desired_count`,
   `ecs_service_running_count`, `ecs_service_pending_count`,
   `ecs_service_rollout_state`, `ecs_service_deployment_failed` and
   `ecs_stopped_tasks{stop_code}` to Pushgateway under `job="ecs"`. The `ecs.yml`
   rules and the **ECS platform** dashboard read them.
2. **Task logs** — `ecs_logs.py` reads the prod log groups under
   `/ecs/<project>-<environment>` with `FilterLogEvents`, ships new lines to Loki
   as `{source="app", service="<service>"}` and checkpoints its position on the
   EFS volume, pushing `ecs_logs_shipped_total`,
   `ecs_logs_last_event_timestamp_seconds` and `ecs_logs_scrape_timestamp_seconds`
   under `job="ecs-logs"`.

Nothing is queried through CloudWatch dashboards, alarms, metric filters or
Insights: the services keep the `awslogs` driver, CloudWatch Logs is only the sink
it already writes to, and an OSS shipper reads it. To keep logs out of CloudWatch
entirely, either add a FireLens sidecar per service (OSS Fluent Bit to Loki, about
$7/month per task at 0.25 vCPU / 0.5 GB) or have the service push straight to
Alloy, then set `enable_ecs_log_shipping = false`.

Task CPU and memory are deliberately not collected: on Fargate without Container
Insights they exist only in the CloudWatch ECS namespace, so the dashboard leans on
service/task state, the blackbox probes and each service's own OTLP metrics.

## RDS (SQL Server) metrics

`rds.tf` schedules a task that reads the prod secret
(`mssql_secret_name`, default `agrovesto-prod-mssql-master`, which already stores
`username`, `password`, `host` and `port`), connects over TDS with the pure-Python
`pytds` client and queries SQL Server DMVs:

| Metric | Source |
| --- | --- |
| `mssql_database_size_bytes{db}` | `sys.master_files` |
| `mssql_user_connections` | `sys.dm_exec_sessions` |
| `mssql_blocked_sessions` | `sys.dm_exec_requests` |
| `mssql_deadlocks_total`, `mssql_logins_total`, `mssql_batch_requests_total`, `mssql_page_life_expectancy_seconds` | `sys.dm_os_performance_counters` |
| `mssql_volume_total_bytes{mount}`, `mssql_volume_available_bytes{mount}` | `sys.dm_os_volume_stats` |
| `mssql_up`, `mssql_scrape_timestamp_seconds` | task itself |

A failed connection is reported as `mssql_up 0` (not a task failure), so
`MssqlUnreachable` is what tells you the database is down. Set
`enable_rds_monitoring = false` to remove the task, its schedule and its rules.

This job also replaces the prod stack's CloudWatch size guard: the instance is
SQL Server Express, which caps every database at 10 GB with no warning from AWS
and no SQL Server Agent to notice, so `mssql_database_size_bytes` above
`mssql_database_size_warning_bytes` (default 8 GiB) raises
`MssqlDatabaseNearSizeLimit`. `prod/terraform.auto.tfvars` therefore ships
`db_size_alarm_enabled = false`, which removes the sqlcmd check task, its log
group, the metric filter, the alarm and the SNS topic on the next prod apply —
flip it back on if you want both paths for a while.

## Deploying

```bash
cd monitoring
terraform init
terraform plan
terraform apply
```

The pipeline (`monitoring.workflow.yml`, installed as
`.github/workflows/monitoring.yml`) does the same on pushes to `main` that touch
`monitoring/**`: fmt, Checkov, Trivy, `terraform test` with a 95% coverage gate,
SonarQube, plan on pull requests, apply on `main`. Every step is blocking — no
`continue-on-error`, no Checkov `soft_fail`.

## Operational notes

- **Redeploy after config changes.** Config lives on EFS, not in the task
  definition; `aws ecs update-service --force-new-deployment` per service.
- **Retention vs volume.** Loki's filesystem retention is 30 days and Prometheus
  keeps 15 days / 10 GB. Both write to the EFS volume, which grows
  elastically; the `mssql` access point exists so the metrics task can read the
  config volume without mounting the whole file system read-write, and `collector`
  holds the log shipper's checkpoint so a restart never re-ships lines.
- **Alertmanager config can contain credentials** (SMTP password), which is why the
  config bucket is CMK-encrypted and the one secret that ECS injects directly (the
  Grafana admin password) stays an SSM `SecureString`.
- **EFS transit encryption is on** for every task, so the mount target opens 2996
  (stunnel) as well as 2049.
- **No CloudWatch dependency for signals.** The only CloudWatch resources are the
  ECS task log group (30 days) and the EventBridge schedules; all metrics, logs,
  traces, alerts and dashboards come from the OSS components above.
- **Prod stack coupling.** The stack discovers prod resources by name
  (`vpc_name`, `alb_name`, `alb_security_group_name`) and reads the prod SQL
  Server secret. Renaming any of those in prod requires the matching variable
  update here.
