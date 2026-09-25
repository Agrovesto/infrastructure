# Committed, secret-free values. Terraform loads this file automatically.

aws_region  = "eu-west-1"
project     = "agrovesto"
environment = "prod"
domain_name = "nomaos.com"

# Names of the prod resources this stack discovers. Change only if prod renames them.
vpc_name                = "agrovesto-prod-vpc"
alb_name                = "agrovesto-prod-alb"
alb_security_group_name = "agrovesto-prod-alb-sg"

grafana_subdomain     = "grafana"
grafana_allowed_cidrs = [] # empty = Grafana is reachable from inside the VPC only
# GitHub login activates when both GRAFANA_GITHUB_CLIENT_ID and
# GRAFANA_GITHUB_CLIENT_SECRET repository secrets are present. Access remains
# subject to grafana_allowed_cidrs. Infrastructure is Admin, team-leads is
# Editor, and Backend/Frontend/mobile are Viewer; unlisted teams are denied.
# See docs/github-sso.md. The generated local admin remains a break-glass login.

# Alerts: with these empty, alerts stay in Alertmanager/Grafana and nothing is
# sent out. Fill them in to start notifying.
alert_email              = ""
alert_smtp_host          = ""
alert_smtp_user          = ""
alertmanager_webhook_url = ""
# Alertmanager -> the prod alerts topic (prod/sns.tf); its email subscribers get
# Prometheus alerts too. Needs the prod stack applied first.
alertmanager_sns_topic = "agrovesto-prod-alerts"

# Cost monitoring: a Cost and Usage Report lands in S3 and a daily task turns it
# into budget metrics in Prometheus. The first data point needs one CUR delivery.
enable_cost_monitoring = true
monthly_budget_usd     = 250
budget_alert_ratio     = 0.8

# Monthly cost/usage/analysis PDF by email (SES). The sending domain is verified
# in Route53 here; fill report_recipients in (or alert_email above) to switch it on.
enable_monthly_report = true
report_recipients     = ["tech@agrovesto.com"]


# Uptime probes (blackbox exporter). Add or remove entries freely.
probe_targets = {
  wallet          = "https://wallet-api.nomaos.com/"
  onboarding      = "https://onboarding-api.nomaos.com/"
  input           = "https://input-api.nomaos.com/"
  moneval         = "https://moneval-api.nomaos.com/"
  serviceprovider = "https://serviceprovider-api.nomaos.com/"
  vault           = "https://vault.nomaos.com/v1/sys/health"
  grafana         = "https://grafana.nomaos.com/api/health"
}

# RDS: the adopted prod instance. Host, port and the ARN of its RDS-managed
# master secret are read from the instance (data source), so no credentials
# are copied into this state. The metrics task runs hourly with no CloudWatch,
# Performance Insights or enhanced monitoring involved.
enable_rds_monitoring     = true
mssql_secret_name         = "" # superseded by the RDS-managed secret of the adopted instance
mssql_instance_identifier = "migration-prod"
mssql_database            = "master"

# Cost levers.
use_fargate_spot       = false
metrics_retention      = "15d"
logs_retention_hours   = 720
traces_retention_hours = 336
