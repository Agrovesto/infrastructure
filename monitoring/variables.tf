variable "aws_region" {
  description = "Region the monitoring stack runs in (the prod region)"
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  type    = string
  default = "agrovesto"
}

variable "environment" {
  description = "Account this stack observes. The monitoring stack lives in the prod account"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "Public zone the Grafana record is created in (owned by the prod stack)"
  type        = string
  default     = "nomaos.com"
}

variable "tags" {
  type    = map(string)
  default = {}
}

# --- Discovery of the prod stack -------------------------------------------------
# The prod stack owns the VPC, ALB and zone. Monitoring reads them by tag/name so
# the two states stay independent; change these if the prod names ever move.

variable "vpc_name" {
  type    = string
  default = "agrovesto-prod-vpc"
}

variable "private_subnet_tier_tag" {
  type    = string
  default = "private"
}

variable "alb_name" {
  type    = string
  default = "agrovesto-prod-alb"
}

variable "alb_security_group_name" {
  description = "ALB security group, so Grafana accepts traffic from the load balancer only"
  type        = string
  default     = "agrovesto-prod-alb-sg"
}

# --- Grafana ---------------------------------------------------------------------

variable "grafana_subdomain" {
  type    = string
  default = "grafana"
}

variable "grafana_allowed_cidrs" {
  description = "CIDRs allowed to reach Grafana through the ALB. Empty = VPC traffic only (use `aws ssm start-session` + tunnel or add your office IP)"
  type        = list(string)
  default     = []
}

variable "grafana_listener_rule_priority" {
  description = "ALB listener-rule priority; the prod stack uses 1..100 for services"
  type        = number
  default     = 900
}

variable "grafana_admin_user" {
  type    = string
  default = "admin"
}

# --- Images ----------------------------------------------------------------------
# Public OSS images only, pinned. Everything runs on Graviton (arm64).

variable "prometheus_version" {
  type    = string
  default = "v3.1.0"
}

variable "alertmanager_version" {
  type    = string
  default = "v0.28.1"
}

variable "loki_version" {
  type    = string
  default = "3.4.2"
}

variable "tempo_version" {
  type    = string
  default = "2.7.1"
}

variable "grafana_version" {
  type    = string
  default = "11.5.2"
}

variable "alloy_version" {
  type    = string
  default = "v1.6.1"
}

variable "blackbox_version" {
  type    = string
  default = "v0.25.0"
}

variable "pushgateway_version" {
  type    = string
  default = "v1.10.0"
}

variable "awscli_version" {
  type    = string
  default = "2.22.35"
}

variable "python_version" {
  type    = string
  default = "3.12-slim"
}

# --- Sizing (Fargate CPU units / MiB) --------------------------------------------

variable "service_sizing" {
  description = "cpu is in Fargate units (256 = 0.25 vCPU). One entry per ECS service; edge carries four containers"
  type = map(object({
    cpu    = number
    memory = number
  }))

  default = {
    prometheus = { cpu = 512, memory = 1024 }
    loki       = { cpu = 512, memory = 1024 }
    tempo      = { cpu = 512, memory = 1024 }
    grafana    = { cpu = 512, memory = 1024 }
    edge       = { cpu = 512, memory = 1024 }
  }
}

variable "use_fargate_spot" {
  description = "Run the stateless collectors (Alloy, blackbox, pushgateway) on Fargate Spot (~70% cheaper, may be interrupted)"
  type        = bool
  default     = false
}

# --- Retention --------------------------------------------------------------------

variable "metrics_retention" {
  type    = string
  default = "15d"
}

variable "metrics_retention_size" {
  type    = string
  default = "10GB"
}

variable "logs_retention_hours" {
  type    = number
  default = 720
}

variable "traces_retention_hours" {
  type    = number
  default = 336
}

variable "log_retention_days" {
  description = "Retention for the monitoring components' own ECS logs"
  type        = number
  default     = 30
}

# --- Alerts -----------------------------------------------------------------------

variable "alert_email" {
  description = "Alertmanager SMTP recipient. Empty = no email receiver"
  type        = string
  default     = ""
}

variable "alert_smtp_host" {
  type    = string
  default = ""
}

variable "alert_smtp_port" {
  type    = number
  default = 587
}

variable "alert_smtp_user" {
  type    = string
  default = ""
}

variable "alert_smtp_from" {
  type    = string
  default = "alerts@nomaos.com"
}

variable "alert_smtp_password" {
  description = "SMTP password; stored as an SSM SecureString, never in state-cleartext tfvars"
  type        = string
  sensitive   = true
  default     = ""
}

variable "alertmanager_webhook_url" {
  description = "Slack/Mattermost-compatible webhook for alerts. Empty = no webhook receiver"
  type        = string
  sensitive   = true
  default     = ""
}

# --- Probes ----------------------------------------------------------------------

variable "probe_targets" {
  description = "Uptime probes (blackbox exporter): name -> URL"
  type        = map(string)

  default = {
    wallet          = "https://wallet.nomaos.com/"
    onboarding      = "https://onboarding-api.nomaos.com/"
    input           = "https://input.nomaos.com/"
    moneval         = "https://moneval.nomaos.com/"
    serviceprovider = "https://serviceprovider.nomaos.com/"
    vault           = "https://vault.nomaos.com/v1/sys/health"
    grafana         = "https://grafana.nomaos.com/api/health"
  }
}

variable "probe_interval_seconds" {
  type    = number
  default = 60
}

variable "tls_expiry_warning_days" {
  type    = number
  default = 21
}

# --- Cost / budgets ---------------------------------------------------------------

variable "enable_cost_monitoring" {
  description = "Create the CUR export, the S3 bucket and the daily budget task"
  type        = bool
  default     = true
}

variable "monthly_budget_usd" {
  description = "Monthly budget the stack reports against and alerts on"
  type        = number
  default     = 250
}

variable "budget_alert_ratio" {
  description = "Alert when month-to-date spend crosses this share of the budget"
  type        = number
  default     = 0.8
}

variable "budget_schedule_expression" {
  description = "EventBridge schedule for the budget task (UTC)"
  type        = string
  default     = "cron(15 6 * * ? *)"
}

variable "cur_report_name" {
  type    = string
  default = "agrovesto-daily"
}

variable "cur_bucket_name" {
  description = "S3 bucket for the Cost and Usage Report. Empty = derived from the account id"
  type        = string
  default     = ""
}

variable "enable_monthly_report" {
  description = "Mail a monthly cost/usage/analysis PDF through SES (needs report_recipients or alert_email)"
  type        = bool
  default     = true
}

variable "report_recipients" {
  description = "Addresses the monthly PDF goes to. Empty = alert_email; if that is empty too the report stays off"
  type        = list(string)
  default     = []
}

variable "report_sender" {
  description = "SES-verified From address for the monthly report. Empty = monitoring@<domain>"
  type        = string
  default     = ""
}

variable "report_ses_domain" {
  description = "Domain verified in SES for the report sender. Empty = domain_name"
  type        = string
  default     = ""
}

variable "report_schedule_expression" {
  description = "EventBridge schedule for the monthly report task (UTC)"
  type        = string
  default     = "cron(0 8 1 * ? *)"
}

# --- Feature toggles --------------------------------------------------------------

# --- RDS / SQL Server metrics ---------------------------------------------------
# The prod secret is created by the prod stack as "<project>-<environment>-mssql-master"
# and stores { username, password, host, port }, so only its name is needed here.
variable "enable_rds_monitoring" {
  description = "Run the scheduled SQL Server metrics task (no CloudWatch, no Performance Insights)"
  type        = bool
  default     = true
}

variable "mssql_secret_name" {
  description = "Name of the prod Secrets Manager secret holding the SQL Server credentials"
  type        = string
  default     = "agrovesto-prod-mssql-master"
}

variable "mssql_instance_identifier" {
  description = "Prod RDS instance identifier. When set, the metrics task reads the host and the RDS-managed master secret from the instance (data source) instead of var.mssql_secret_name."
  type        = string
  default     = ""
}

variable "mssql_database" {
  description = "Database the metrics queries run against (DMVs are server-wide)"
  type        = string
  default     = "master"
}

variable "mssql_database_size_warning_bytes" {
  description = "Per-database size that raises MssqlDatabaseNearSizeLimit. The prod instance is Express, which caps every database at 10 GB"
  type        = number
  default     = 8589934592
}

variable "mssql_schedule_expression" {
  description = "How often the SQL Server metrics task runs"
  type        = string
  default     = "rate(1 hour)"
}

variable "enable_logs" {
  description = "Run Loki (and the Alloy log pipeline)"
  type        = bool
  default     = true
}

variable "enable_traces" {
  description = "Run Tempo (and the Alloy OTLP pipeline)"
  type        = bool
  default     = true
}

# --- ECS platform monitoring -----------------------------------------------------

variable "enable_ecs_monitoring" {
  description = "Run the scheduled ECS collector (cluster and service state, service logs)"
  type        = bool
  default     = true
}

variable "enable_ecs_log_shipping" {
  description = "Also ship the prod ECS task logs from CloudWatch Logs into Loki"
  type        = bool
  default     = true
}

variable "ecs_cluster_name" {
  description = "Cluster the collector reads. Empty means <project>-<environment>"
  type        = string
  default     = ""
}

variable "ecs_log_group_prefix" {
  description = "Log group prefix whose groups are shipped to Loki. Empty means /ecs/<project>-<environment>"
  type        = string
  default     = ""
}

variable "collector_schedule_expression" {
  description = "How often the ECS collector runs"
  type        = string
  default     = "rate(2 minutes)"
}

variable "ecs_log_lookback_minutes" {
  description = "How far back the log shipper may read after a cold start"
  type        = number
  default     = 15
}
