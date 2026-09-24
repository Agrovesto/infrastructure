# -----------------------------------------------------------------------------
# Auto-loaded values for CI (GitHub Actions) AND local runs — PROD.
# -----------------------------------------------------------------------------
# The PROD account is authoritative for the root domain: this stack creates the
# hosted zone and every record in it (prod service aliases AND the dev hosts —
# dev manages no DNS itself; see the extra_a_records block below).
# ACTION: delegate the registrar NS records for this domain to the zone created
# here (see the `route53_name_servers` output).
domain_name = "nomaos.com"

# --- ECS services (one Fargate service per dev API name) ---------------------
# service name == database name (dev convention).
#
# TODO: the `image` values below are a PLACEHOLDER image that serves HTTP on
# $PORT so the ALB health checks pass on first apply. Build and push your real
# images to the ECR repos (agrovesto-prod-<svc>) and update these to
#   <account-id>.dkr.ecr.eu-west-1.amazonaws.com/agrovesto-prod-<svc>:<tag>
#
# ARM64 REQUIRED (tasks run on Graviton): build every image for linux/arm64 —
#   docker buildx build --platform linux/arm64 -t agrovesto-prod-<svc>:<tag> .
# An amd64-only image starts and dies immediately with "exec format error".
# cpu 256 / memory 512 is already the smallest Fargate task that exists.
services = {
  wallet = {
    image         = "ealen/echo-server:latest"
    port          = 5001
    cpu           = 256
    memory        = 512
    desired_count = 1
    subdomain     = "wallet-api"
    environment   = { ASPNETCORE_ENVIRONMENT = "Production", ASPNETCORE_URLS = "http://+:5001" }
  }
  onboarding = {
    image         = "ealen/echo-server:latest"
    port          = 5002
    cpu           = 256
    memory        = 512
    desired_count = 1
    subdomain     = "onboarding-api"
    environment   = { ASPNETCORE_ENVIRONMENT = "Production", ASPNETCORE_URLS = "http://+:5002" }
  }
  input = {
    image         = "ealen/echo-server:latest"
    port          = 5003
    cpu           = 256
    memory        = 512
    desired_count = 1
    subdomain     = "input-api"
    environment   = { ASPNETCORE_ENVIRONMENT = "Production", ASPNETCORE_URLS = "http://+:5003" }
  }
  moneval = {
    image         = "ealen/echo-server:latest"
    port          = 5004
    cpu           = 256
    memory        = 512
    desired_count = 1
    subdomain     = "moneval-api"
    environment   = { ASPNETCORE_ENVIRONMENT = "Production", ASPNETCORE_URLS = "http://+:5004" }
  }
  serviceprovider = {
    image         = "ealen/echo-server:latest"
    port          = 5005
    cpu           = 256
    memory        = 512
    desired_count = 1
    subdomain     = "serviceprovider-api"
    environment   = { ASPNETCORE_ENVIRONMENT = "Production", ASPNETCORE_URLS = "http://+:5005" }
  }
}

# --- RDS SQL Server databases (same names as dev) -----------------------------
mssql_databases = ["wallet", "onboarding", "input", "moneval", "serviceprovider"]

# --- ECR (API image repos) ---------------------------------------------------
# Repos are created from the `apis` map above (agrovesto-dev-<svc>). Push with
# `terraform output ecr_repository_urls`; the EC2 host self-authenticates.
ecr_image_tag_mutability = "IMMUTABLE" # prod: release tags cannot be overwritten
ecr_force_delete         = false       # prod: never delete repos that still hold images
ecr_images_to_keep       = 5           # tagged images retained per repo


# --- HA mode: SINGLE-AZ for now -------------------------------------------------
# RDS primary and all ECS tasks run in a single AZ (cost). For go-live HA flip
# these and apply: mssql_multi_az = true, single_az_ecs = false.
mssql_multi_az = false
single_az_ecs  = true

# --- Cost tuning ----------------------------------------------------------------
# CloudWatch: 30-day retention for service logs and VPC flow logs.
log_retention_days = 30

# One shared NAT gateway instead of one per AZ: saves ~$35/mo, costs AZ
# redundancy on private-subnet egress. Flip to false for go-live HA.
single_nat_gateway = true

# --- ECS autoscaling ------------------------------------------------------------
# One task stays warm per service (the ALB cannot wake a service from zero —
# with no healthy target it returns 503), scaling out on request load up to 4
# tasks. Tune requests-per-task once there is real traffic.
ecs_autoscaling_enabled           = true
ecs_autoscaling_min_capacity      = 1
ecs_autoscaling_max_capacity      = 5
ecs_autoscaling_requests_per_task = 1000

# --- RDS: SQL Server Express on db.t3.micro, 20 GB with a 50 GB ceiling -------
# The Express licence is free, so the database costs the bare instance rate:
# db.t3.micro (2 vCPU / 1 GiB) + 20 GB gp3 is ~$15/mo, against ~$450/mo for the
# smallest Standard (db.m7i.large).
#
# What Express costs you (all hard SQL Server limits):
#   - 10 GB max per database  <-- the one to watch; writes fail at the cap
#   - ~1.4 GB buffer pool, 4 cores max
#   - no SQL Server Agent (schedule recurring work in the app, e.g. Hangfire)
#   - NO Multi-AZ on RDS at all (Standard/Enterprise only)
#
# What db.t3.micro costs you beyond that: 1 GiB of RAM total. Step up to
# db.t3.small (2 GiB) for ~$13/mo more if the instance thrashes — one variable,
# a few minutes of downtime.
#
# Upgrade path (never in-place): snapshot -> restore as sqlserver-web or
# sqlserver-se on db.m7i.large -> rename to keep the endpoint. Trigger: any
# single database approaching 8 GB, or the day you need Multi-AZ.
mssql_engine         = "sqlserver-ex"
mssql_instance_class = "db.t3.micro"
# Storage: see the Adoption section at the end (values of migration-prod).

# Express has no SQL Server Agent, so there is no agent log to publish.
mssql_enabled_cloudwatch_logs_exports = ["error"]

# --- SQL Server Express 10 GB guard --------------------------------------------
# DB size is now watched by the open-source monitoring stack: the hourly DMV job
# publishes mssql_database_size_bytes and
#   mssql_database_size_warning_bytes (default 8 GiB, see monitoring/README.md)
# raises MssqlDatabaseNearSizeLimit through Alertmanager. The CloudWatch metric
# filter + alarm + SNS path below is therefore off; flip this back to true (and
# apply) if you ever want the native path alongside it.
db_size_alarm_enabled = false
# db_size_alarm_email = "ops@agrovesto.com"
# db_size_check_schedule     = "rate(12 hours)"
# db_size_alarm_threshold_mb = 8192

# --- Vault ----------------------------------------------------------------------
# Vault (secrets store) is provisioned by default; services still get DB creds
# injected from Secrets Manager until Vault is initialized. Bootstrap steps and
# the switch to vault_secrets_enabled = true are documented in vault.tf.
# enable_vault           = false   # to remove the Vault service entirely
# vault_secrets_enabled  = true    # after `vault operator init` + kv bootstrap

# Flip to true once the instance exists and you want Terraform to create the 5
# databases automatically (runs a one-off Fargate task via the AWS API).
# run_db_init = true

# --- Dev DNS records (managed from THIS zone) ---------------------------------
# Dev runs under the dev.<domain> subdomain and creates no DNS of its own.
# Fill these from the dev stack outputs after a dev apply:
#   terraform -chdir=../dev output ec2_public_ip frontend_default_domains
#
# extra_a_records = {
#   "dev-wallet-api"          = "<dev EC2 Elastic IP>"
#   "dev-onboarding-api"      = "<dev EC2 Elastic IP>"
#   "dev-input.api"           = "<dev EC2 Elastic IP>"
#   "dev-moneval-api"         = "<dev EC2 Elastic IP>"
#   "dev-serviceprovider-api" = "<dev EC2 Elastic IP>"
#   "dev-vault"                = "<dev EC2 Elastic IP>"
#   # The dev logging stack's Grafana (nginx vhost on the dev host). Without this
#   # record the UI is still reachable through the SSH tunnel printed by
#   # `terraform -chdir=../dev output logging_access`.
#   "dev-logs"                 = "<dev EC2 Elastic IP>"
# }
# extra_cname_records = {
#   "landing.dev"    = "dev.<landing Amplify default domain>"
#   "onboarding.dev" = "dev.<onboarding Amplify default domain>"
# }

# =============================================================================
# Adoption of existing resources (docs/import-runbook.md, discovery 2026-09-23)
# Every value below is the REAL value of the adopted resource. Many of these
# attributes are ForceNew, so changing one means replacing the resource.
# =============================================================================

# --- Network: vpc-0016f521bae08f4ff ------------------------------------------
vpc_cidr              = "172.96.0.0/16"
public_subnet_cidrs   = ["172.96.0.0/24", "172.96.1.0/24"]   # existing, IGW-routed
database_subnet_cidrs = ["172.96.2.0/24", "172.96.3.0/24"]   # existing, hold migration-prod
private_subnet_cidrs  = ["172.96.11.0/24", "172.96.12.0/24"] # NEW (ECS tasks), behind the new NAT

# The default SG carries 8 live rules and is attached to migration-prod and
# the noma-agx EC2 host. Do not strip it; it is imported as legacy, as-is.
manage_default_security_group = false

# --- RDS: migration-prod -------------------------------------------------------
mssql_identifier                   = "migration-prod"
mssql_engine_version               = "15.00.4445.1.v1"
mssql_allocated_storage_gb         = 50
mssql_max_allocated_storage_gb     = 63
mssql_storage_type                 = "gp2"
mssql_master_username              = "agrovesto"
mssql_subnet_group_name            = "agxdb2subnetgroup"
mssql_performance_insights_enabled = true  # live instance has it on (import plan)

# !! migration-prod is NOT encrypted. storage_encrypted is ForceNew, so it must
# stay false until the planned encrypt-by-restore window (docs/import-runbook.md §5).
mssql_storage_encrypted = false

# Keep the instance's current SGs (default SG + rds-ec2-3) next to the design's
# RDS SG, so the EC2 -> DB paths in use today keep working. Remove them once
# the apps connect through the ECS SG.
mssql_additional_security_group_ids = ["sg-05a2722a050c1109b", "sg-0b555edfc6d445a18"]

# --- Match the live resources (import plan 2026-09-23) ------------------
# Password stays as it is today; do NOT switch to an RDS-managed secret here,
# that rotates the live password. nomaosDBcredentials holds the migration-prod
# login (confirmed by owner 2026-09-24; agxdb2DBcredentials no longer exists).
mssql_manage_master_user_password = false
mssql_existing_master_secret_arn  = "arn:aws:secretsmanager:eu-west-1:221434544570:secret:nomaosDBcredentials-GIwHiK"
mssql_monitoring_role_arn         = "arn:aws:iam::221434544570:role/rds-monitoring-role"
mssql_backup_window               = "04:13-04:43"
mssql_maintenance_window          = "mon:22:43-mon:23:13"
mssql_subnet_group_description    = "Subnet group for agxdb2 RDS instance"
public_subnet_map_public_ip       = true

# --- SNS (sns.tf, alarms.tf) ---------------------------------------------------
# Each address gets an AWS confirmation email; alerts start once it is clicked.
alert_emails   = ["tech@agrovesto.com"]
app_sns_topics = ["notifications"]
