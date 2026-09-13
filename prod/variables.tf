# =============================================================================
# Variables — Agrovesto prod stack (flat root module, like dev/)
#
# Same conventions as the dev stack: a single flat root module, one variables
# file for the environment and everything the services need.
# =============================================================================

# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project" {
  type    = string
  default = "agrovesto"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "domain_name" {
  description = "Root domain for all services (must match the Route53 hosted zone / registrar)"
  type        = string
}

variable "tags" {
  description = "Extra tags merged into every resource (on top of Project/Environment)"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Network (VPC)
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "One public subnet per entry (ALB lives here); AZs are picked in order"
  type        = list(string)
  default     = ["10.30.1.0/24", "10.30.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "One private subnet per entry (ECS Fargate tasks live here); must be >= 2 for the ALB"
  type        = list(string)
  default     = ["10.30.11.0/24", "10.30.12.0/24"]
}

variable "database_subnet_cidrs" {
  description = "Dedicated private subnets for RDS (must be >= 2 for the DB subnet group)"
  type        = list(string)
  default     = ["10.30.21.0/24", "10.30.22.0/24"]
}

variable "single_nat_gateway" {
  description = "true: one NAT gateway shared by all AZs (cheaper). false (default/prod): one NAT per AZ for HA"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# ECS services (Fargate, private subnets, behind the ALB)
#
# Keys match the dev API names, so service name == database name,
# exactly like the dev stack.
# -----------------------------------------------------------------------------

variable "services" {
  description = "ECS Fargate services behind the ALB. Add a key to launch another service."
  type        = map(object({
    image             = string
    port              = number
    cpu               = number
    memory            = number
    desired_count     = number
    subdomain         = string
    health_check_path = optional(string, "/")
    environment       = optional(map(string), {})
  }))
}

variable "enable_container_insights" {
  type    = bool
  default = true
}

variable "single_az_ecs" {
  description = "true: run every ECS task in the FIRST private subnet/AZ only (cheap single-AZ mode for now). false: spread tasks across all private subnets/AZs"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# ECS autoscaling
#
# Every service keeps one warm task (the ALB cannot wake a service from zero:
# with no healthy target it just returns 503) and scales out on ALB request
# load. Vault never scales — one raft writer only.
# -----------------------------------------------------------------------------

# Fargate task CPU architecture. ARM64 (Graviton) is ~20% cheaper per vCPU and
# per GB than x86, and .NET 6/8 run natively on linux-arm64.
#
# REQUIREMENT: every image must be built for linux/arm64. An amd64-only image
# on an ARM64 task fails at start-up with "exec format error". Build with
#   docker buildx build --platform linux/arm64 ...
# (or push a multi-arch manifest). The db-init task is deliberately left on
# x86 — mcr.microsoft.com/mssql-tools ships amd64 only.
variable "ecs_cpu_architecture" {
  type    = string
  default = "ARM64"
}

variable "ecs_operating_system_family" {
  type    = string
  default = "LINUX"
}

variable "ecs_autoscaling_enabled" {
  description = "Attach an Application Auto Scaling target + request-count policy to every service"
  type        = bool
  default     = true
}

variable "ecs_autoscaling_min_capacity" {
  description = "Tasks kept warm. 0 means the ALB 503s until something scales the service up, which nothing does automatically."
  type        = number
  default     = 1
}

variable "ecs_autoscaling_max_capacity" {
  description = "Upper bound on tasks per service"
  type        = number
  default     = 4
}

variable "ecs_autoscaling_requests_per_task" {
  description = "Target ALB requests per minute per task (1000 ≈ 16 rps per task). Lower = more tasks."
  type        = number
  default     = 1000
}

variable "ecs_autoscaling_scale_in_cooldown" {
  description = "Seconds to wait before scaling in again (slow, so a brief lull does not drop tasks)"
  type        = number
  default     = 300
}

variable "ecs_autoscaling_scale_out_cooldown" {
  description = "Seconds to wait before scaling out again (fast, so load spikes are absorbed)"
  type        = number
  default     = 60
}

variable "log_retention_days" {
  description = "CloudWatch log retention for service logs and VPC flow logs (prod baseline: 1 year, CKV_AWS_338)"
  type        = number
  default     = 365
}

# -----------------------------------------------------------------------------
# ECR
# -----------------------------------------------------------------------------

variable "ecr_image_tag_mutability" {
  description = "IMMUTABLE for prod (release tags can't be overwritten)"
  type        = string
  default     = "IMMUTABLE"
}

variable "ecr_force_delete" {
  description = "Allow terraform destroy to delete repos that still contain images (leave false in prod)"
  type        = bool
  default     = false
}

variable "ecr_images_to_keep" {
  description = "How many tagged images to retain per repository"
  type        = number
  default     = 3
}

# -----------------------------------------------------------------------------
# RDS (SQL Server) — one instance hosting the same 5 databases as dev
# -----------------------------------------------------------------------------

# sqlserver-se (Standard)  — ~$450/mo on db.m7i.large (2 vCPU / 8 GiB floor).
#                            No per-database size cap, SQL Server Agent, and
#                            Multi-AZ is available. The licence is most of the
#                            cost, and it is charged per vCPU.
# sqlserver-ex (Express)   — free licence, so it costs the bare instance rate
#                            (~$15/mo on db.t3.micro). Legal in production.
#                            Limits: 10 GB per database, ~1.4 GB buffer pool,
#                            4 cores, no SQL Server Agent, and no Multi-AZ on
#                            RDS at all.
# sqlserver-web (Web)      — ~$60-90/mo on db.t3.small. Bigger than Express
#                            (no 10 GB cap) but Microsoft licenses it only for
#                            public internet-facing web apps, not line-of-
#                            business applications.
# sqlserver-ee (Enterprise)
#
# There is NO in-place edition change on RDS. Upgrading = snapshot -> restore as
# the new edition -> rename to keep the endpoint. Downgrading = native
# backup/restore or DMS into a new instance.
variable "mssql_engine" {
  description = "sqlserver-ex (Express), sqlserver-web (Web), sqlserver-se (Standard), sqlserver-ee (Enterprise)"
  type        = string
  default     = "sqlserver-ex"
}

variable "mssql_engine_version" {
  description = "Leave null to let AWS pick the default version for the engine"
  type        = string
  default     = null
}

# db.t3.micro = 2 vCPU / 1 GiB, the smallest instance SQL Server runs on at
# all. With the free Express licence that is ~$15/mo for the whole database.
#
# Instance classes per edition (AWS "DB instance class support for Microsoft SQL
# Server"):
#   Express  db.t3.micro  - db.t3.xlarge
#   Web      db.t3.small  - db.t3.xlarge
#   Standard db.t3.xlarge - db.t3.2xlarge, db.m5/m6i/m7i.large+ (2 vCPU / 8 GiB)
# So db.t3.micro and db.t3.small exist only for Express and Web.
#
# The real constraint here is RAM, not licence: 1 GiB total, of which the OS and
# the RDS monitoring agent take a few hundred MB, leaves ~600-700 MB for SQL
# Server — under the 1.4 GB buffer pool Express would otherwise allow. Fine for
# light traffic; if it thrashes, db.t3.small (2 GiB) is one variable and about
# $13/mo more, applied with a short reboot. See the step_up_to_small test run.
variable "mssql_instance_class" {
  type    = string
  default = "db.t3.micro"
}

# 20 GiB is the documented minimum for every SQL Server edition on gp3/gp2. gp3
# still delivers 3,000 baseline IOPS at any size, and autoscaling covers
# growth up to var.mssql_max_allocated_storage_gb.
variable "mssql_allocated_storage_gb" {
  type    = number
  default = 20
}

variable "mssql_max_allocated_storage_gb" {
  description = "Storage autoscaling ceiling (0 disables autoscaling)"
  type        = number
  default     = 50
}

variable "mssql_port" {
  type    = number
  default = 1433
}

variable "mssql_multi_az" {
  description = "Standby replica in a second AZ (prod default: on)"
  type        = bool
  default     = false
}

variable "mssql_master_username" {
  description = "RDS master user ('sa' is reserved on RDS)"
  type        = string
  default     = "agrovestoadmin"
}

variable "mssql_databases" {
  description = "Databases created on the RDS SQL Server instance (same names as dev)"
  type        = list(string)
}

# "error" and "agent" are the only log types SQL Server publishes to
# CloudWatch. Express has no SQL Server Agent, so prod pins this to ["error"];
# put "agent" back if and when the edition moves to Standard.
variable "mssql_enabled_cloudwatch_logs_exports" {
  type    = list(string)
  default = ["error", "agent"]
}

variable "mssql_backup_retention_days" {
  type    = number
  default = 30
}

variable "mssql_skip_final_snapshot" {
  description = "false = RDS takes a final snapshot on destroy (prod-safe). Set true only for throwaway environments."
  type        = bool
  default     = false
}

variable "run_db_init" {
  description = "After creating RDS, run a one-off Fargate task that creates the databases in var.mssql_databases. Runs from the CI runner via the AWS API, no VPC access needed on the runner."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# HashiCorp Vault (secrets store for the services)
# -----------------------------------------------------------------------------

variable "enable_vault" {
  description = "Run the Vault service (Fargate, raft on EFS, KMS auto-unseal) behind the ALB"
  type        = bool
  default     = true
}

variable "vault_secrets_enabled" {
  description = "true: services read DB creds from Vault (no Secrets Manager injection). Enable AFTER Vault is initialized and the kv paths populated — see vault.tf"
  type        = bool
  default     = false
}

variable "vault_image" {
  type    = string
  default = "hashicorp/vault:1.15"
}

# 256 / 512 is the Fargate floor for any task (x86 or ARM).
variable "vault_cpu" {
  type    = number
  default = 256
}

variable "vault_memory" {
  type    = number
  default = 512
}

variable "vault_subdomain" {
  type    = string
  default = "vault"
}

variable "vault_port" {
  type    = number
  default = 8200
}

# -----------------------------------------------------------------------------
# Deletion protection
# -----------------------------------------------------------------------------

variable "deletion_protection" {
  description = "Deletion protection for the ALB and RDS instance (prod default: on). Set false, apply, THEN destroy when tearing down."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# ALB / TLS
# -----------------------------------------------------------------------------

variable "alb_idle_timeout_seconds" {
  type    = number
  default = 60
}

variable "alb_tls_policy" {
  description = "Security policy for the HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "alb_logs_retention_days" {
  description = "How long ALB access logs stay in S3"
  type        = number
  default     = 90
}

# -----------------------------------------------------------------------------
# Route 53
# -----------------------------------------------------------------------------

variable "create_hosted_zone" {
  type    = bool
  default = true
}

variable "existing_zone_id" {
  description = "Use an existing hosted zone instead of creating one (e.g. the zone lives in another account)"
  type        = string
  default     = ""
}

variable "dns_ttl" {
  type    = number
  default = 300
}

variable "extra_a_records" {
  description = "Plain A records managed from this zone, e.g. the dev hosts -> dev EC2 Elastic IP (name => ipv4)"
  type        = map(string)
  default     = {}
}

variable "extra_cname_records" {
  description = "CNAME records managed from this zone, e.g. the dev Amplify frontends (name => target)"
  type        = map(string)
  default     = {}
}

variable "extra_alias_records" {
  description = "Additional alias A records (name => {name, zone_id, evaluate_target_health})"
  type        = map(object({
    name                   = string
    zone_id                = string
    evaluate_target_health = optional(bool, false)
  }))
  default     = {}
}

# -----------------------------------------------------------------------------
# SQL Server Express 10 GB guard (prod/db_size_alarm.tf)
# -----------------------------------------------------------------------------

variable "db_size_alarm_enabled" {
  description = "Schedule a task that checks every database's size and alarms as one nears the Express 10 GB cap"
  type        = bool
  default     = true
}

variable "db_size_check_schedule" {
  description = "EventBridge schedule expression for the database size check"
  type        = string
  default     = "rate(12 hours)"
}

# Express caps each database at 10240 MB and writes fail at the cap, so the
# threshold has to leave time to react: 8192 MB is roughly one week at 100 MB/day.
variable "db_size_alarm_threshold_mb" {
  type    = number
  default = 8192
}

variable "db_size_alarm_email" {
  description = "Where to send size alarms. Empty = the alarm is visible in CloudWatch but notifies nobody."
  type        = string
  default     = ""
}

variable "db_size_check_image" {
  description = "Image providing sqlcmd. Must be amd64: this task runs on x86_64."
  type        = string
  default     = "mcr.microsoft.com/mssql-tools:latest"
}
