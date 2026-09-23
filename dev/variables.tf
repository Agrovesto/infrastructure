# =============================================================================
# Variables — Agrovesto dev stack (flat root module)
#
# Every file in this repository lives in the root directory: there is no
# `modules/` or `environments/` tree any more. This file therefore holds the
# inputs of what used to be the environment *and* all of its modules.
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
  default = "dev"
}

variable "domain_name" {
  description = "Root domain for all apps (frontends + backends)"
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
  default = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "One public subnet per entry; AZs are picked in order"
  type        = list(string)
  default     = ["10.20.1.0/24"]
}

# -----------------------------------------------------------------------------
# Security groups
# -----------------------------------------------------------------------------

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to SSH to the EC2 instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# -----------------------------------------------------------------------------
# Backups (S3)
# -----------------------------------------------------------------------------

variable "backup_force_destroy" {
  description = "Allow terraform destroy to empty the backup bucket (dev only)"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  type    = number
  default = 14
}

# -----------------------------------------------------------------------------
# EC2 app host
# -----------------------------------------------------------------------------

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ami_id" {
  description = "Leave empty to use the latest Ubuntu 24.04 LTS (noble) AMI from Canonical"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "EC2 key pair name. Optional if using SSM."
  type        = string
  default     = ""
}

variable "root_volume_size_gb" {
  description = "OS + apps disk"
  type        = number
  default     = 50
}

variable "mssql_volume_size_gb" {
  description = "Dedicated MSSQL data disk"
  type        = number
  default     = 50
}

variable "mssql_volume_device" {
  type    = string
  default = "/dev/sdf"
}

variable "ecr_image_tag_mutability" {
  description = "MUTABLE in dev so :latest can be re-pushed (prod is IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "ecr_force_delete" {
  description = "Allow terraform destroy to delete repos that still contain images (dev is disposable)"
  type        = bool
  default     = true
}

variable "ecr_images_to_keep" {
  description = "How many tagged images to retain per repository"
  type        = number
  default     = 3
}

variable "associate_elastic_ip" {
  description = "Attach an Elastic IP to the app host (needed for stable DNS)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Backend APIs (docker containers behind nginx)
# -----------------------------------------------------------------------------

variable "apis" {
  description = "Backend APIs on the EC2 docker host. Add a key to launch another API."
  type = map(object({
    image     = string
    host_port = number
    subdomain = string
    env       = optional(map(string), {})
  }))
}

# -----------------------------------------------------------------------------
# MSSQL
# -----------------------------------------------------------------------------

variable "mssql_sa_password" {
  description = "SA password. Injected via TF_VAR_mssql_sa_password in CI."
  type        = string
  sensitive   = true
}

variable "mssql_databases" {
  description = "Databases created on the single MSSQL instance"
  type        = list(string)
}

variable "mssql_image" {
  type    = string
  default = "mcr.microsoft.com/mssql/server:2022-latest"
}

# Developer Edition: free, full Enterprise feature set, licensed for dev/test
# only — never for production. That makes dev a superset of whatever prod runs,
# which is the point: code that works here does not hit edition limits later.
#
# Flip to "Express" (or "Standard") when dev needs to mirror prod's limits
# exactly, e.g. to reproduce a 10 GB-per-database problem.
#
# NOTE: MSSQL_PID is only read the first time the container initialises
# /var/opt/mssql. On an existing dev host the data volume keeps its original
# edition until the volume is recreated or an in-place edition upgrade is run.
variable "mssql_pid" {
  type    = string
  default = "Developer"

  validation {
    condition     = contains(["Developer", "Express", "Standard", "Enterprise", "Web"], var.mssql_pid)
    error_message = "MSSQL_PID must be one of Developer, Express, Standard, Enterprise, Web."
  }
}

variable "mssql_host_port" {
  type    = number
  default = 1433
}

variable "mssql_subdomain" {
  type    = string
  default = "mssql"
}

# -----------------------------------------------------------------------------
# Vault
# -----------------------------------------------------------------------------

variable "vault" {
  type = object({
    image     = optional(string, "hashicorp/vault:1.15")
    host_port = optional(number, 8200)
    subdomain = optional(string, "vault")
  })
  default = {
    image     = "hashicorp/vault:1.15"
    host_port = 8200
    subdomain = "vault"
  }
}

# -----------------------------------------------------------------------------
# EventBridge Scheduler (start/stop the EC2 host)
# -----------------------------------------------------------------------------

variable "scheduler_timezone" {
  type    = string
  default = "Africa/Lagos"
}

variable "ec2_start_cron" {
  description = "EventBridge Scheduler cron (6 fields) to start the instance"
  type        = string
  default     = "cron(0 8 ? * MON-FRI *)"
}

variable "ec2_stop_cron" {
  description = "EventBridge Scheduler cron (6 fields) to stop the instance"
  type        = string
  default     = "cron(0 20 ? * MON-FRI *)"
}

variable "enable_ec2_scheduler" {
  type    = bool
  default = true
}

# -----------------------------------------------------------------------------
# Amplify frontends
# -----------------------------------------------------------------------------

variable "amplify_apps" {
  description = "Amplify frontends. Add another map key to create a new app."
  type = map(object({
    name                  = optional(string) # defaults to the map key; set to an adopted app's real name
    platform              = optional(string, "WEB")
    repository            = string
    branch                = optional(string, "main")
    subdomain             = string
    framework             = optional(string, "React")
    build_spec            = optional(string)
    environment_variables = optional(map(string), {})
    enable_auto_build     = optional(bool, true)
  }))
}

variable "github_access_token" {
  description = "GitHub PAT for Amplify source. Leave empty to skip connecting a repo."
  type        = string
  default     = ""
  sensitive   = true
}

variable "amplify_enable_custom_domain" {
  description = "Let Amplify manage the custom domain. Off by default: Route53 CNAMEs are used instead so several apps can share one parent domain."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Route 53
# -----------------------------------------------------------------------------

variable "manage_dns" {
  description = "false = create no Route53 zone/records at all (DNS is managed from the prod account's zone; see prod/terraform.auto.tfvars)"
  type        = bool
  default     = true
}

variable "create_hosted_zone" {
  type    = bool
  default = true
}

variable "existing_zone_id" {
  description = "Use an existing hosted zone instead of creating one"
  type        = string
  default     = ""
}

variable "dns_ttl" {
  type    = number
  default = 300
}

variable "extra_a_records" {
  description = "Additional A records (name => ipv4). Merged over the generated ones."
  type        = map(string)
  default     = {}
}

variable "extra_cname_records" {
  description = "Additional CNAME records (name => target). Merged over the generated ones."
  type        = map(string)
  default     = {}
}

variable "extra_alias_records" {
  description = "Additional alias A records (name => {name, zone_id, evaluate_target_health})"
  type = map(object({
    name                   = string
    zone_id                = string
    evaluate_target_health = optional(bool, false)
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Logging & metrics on the host (Loki + Alloy + Grafana + Prometheus)
#
# The whole stack runs as docker containers on the app EC2 instance: it is
# rendered into user_data by dev/locals.tf, so there is no separate host, no
# EKS/ECS, and no AWS logging service involved. Set logging.enabled = false to
# take every bit of it out of the plan.
# -----------------------------------------------------------------------------

variable "logging" {
  description = <<-EOT
    On-host logging and metrics: Loki stores the logs and answers LogQL, Alloy
    collects them (docker containers + journald + an optional push endpoint),
    Grafana visualises and queries them, and Prometheus/cAdvisor/node-exporter
    add the host and per-container metrics the dashboards sit on top of.
  EOT

  type = object({
    enabled = optional(bool, true)

    # Pinned to the same versions the prod monitoring/ stack runs, so a query
    # that works here works there. No :latest — a rebuilt container must not
    # change what the dev logs look like.
    loki_image          = optional(string, "grafana/loki:3.4.2")
    alloy_image         = optional(string, "grafana/alloy:v1.6.1")
    grafana_image       = optional(string, "grafana/grafana-oss:11.5.2")
    prometheus_image    = optional(string, "prom/prometheus:v3.1.0")
    cadvisor_image      = optional(string, "ghcr.io/google/cadvisor:v0.57.0")
    node_exporter_image = optional(string, "prom/node-exporter:v1.9.1")

    # Published on 127.0.0.1 on the host only, and the security group has no
    # ingress for any of them: this is an SSH-tunnel or nginx-only surface.
    loki_port          = optional(number, 3100)
    alloy_port         = optional(number, 12345)
    alloy_push_port    = optional(number, 3101)
    grafana_port       = optional(number, 3000)
    prometheus_port    = optional(number, 9090)
    cadvisor_port      = optional(number, 8080)
    node_exporter_port = optional(number, 9100)

    # --- reaching the UI ------------------------------------------------------
    expose_via_nginx  = optional(bool, true)
    grafana_subdomain = optional(string, "dev-logs")

    # Sources allowed to reach the Grafana vhost through nginx. Empty means
    # 127.0.0.1 only — the UI is then reachable over an SSH tunnel and from
    # nowhere else. Add one CIDR per office/VPN exit to open it up; nothing here
    # is ever exposed without a login, since Grafana keeps its own auth.
    allowed_cidrs = optional(list(string), [])

    # --- retention ------------------------------------------------------------
    # Loki's compactor and Prometheus' TSDB delete on these numbers; the volume
    # they live on is small on purpose (see volume_size_gb).
    loki_retention_days       = optional(number, 14)
    system_retention_days     = optional(number, 5)
    prometheus_retention      = optional(string, "14d")
    prometheus_retention_size = optional(string, "3GB")

    # --- ingest budget ---------------------------------------------------------
    # This box is 2 vCPU / 4 GiB and SQL Server lives here too, so the numbers
    # below are deliberately small: a logger that misbehaves gets rate-limited by
    # Loki rather than taking the APIs down with it.
    loki_ingestion_rate_mb  = optional(number, 4)
    loki_stream_rate_mb     = optional(number, 1)
    loki_max_entries        = optional(number, 2000)
    querier_max_concurrent  = optional(number, 2)
    scrape_interval_seconds = optional(number, 30)
    journal_max_age         = optional(string, "12h")
    journal_max_use         = optional(string, "500M")

    # Services whose log lines are one JSON object each (nginx is always one of
    # them, because of the access log format in nginx.conf). Their fields become
    # Loki labels; anything not listed stays a plain line, which is still fully
    # searchable — only less aggregateable.
    json_log_services = optional(list(string), [])

    # --- disk ------------------------------------------------------------------
    # A volume of its own, so a replacement of the instance does not throw the
    # logs away and log I/O never competes with SQL Server's data files.
    volume_size_gb = optional(number, 20)
    volume_device  = optional(string, "/dev/sdg")

    # Per-container caps, one entry per observability container. These are the
    # difference between "the logging stack is cheap to run" and "the box died".
    cpu_limits = optional(map(string), {
      loki          = "0.50"
      alloy         = "0.25"
      grafana       = "0.50"
      prometheus    = "0.50"
      cadvisor      = "0.25"
      node-exporter = "0.10"
    })
    memory_limits_mb = optional(map(number), {
      loki          = 384
      alloy         = 192
      grafana       = 192
      prometheus    = 384
      cadvisor      = 128
      node-exporter = 48
    })

    # --- the containers' own logs ---------------------------------------------
    # Docker's json-file rotation, set daemon-wide in user_data. The collector
    # reads those files, so they have to exist and have to stay small.
    docker_log_max_size  = optional(string, "10m")
    docker_log_max_files = optional(number, 3)

    # --- Grafana ----------------------------------------------------------------
    grafana_admin_user     = optional(string, "admin")
    grafana_admin_password = optional(string, "agrovesto-dev") # ggignore - dev-only default, override via TF_VAR_logging
  })

  default = {}

  validation {
    condition = alltrue([
      for k in ["loki", "alloy", "grafana", "prometheus", "cadvisor", "node-exporter"] :
      contains(keys(var.logging.cpu_limits), k) && contains(keys(var.logging.memory_limits_mb), k)
    ])
    error_message = "cpu_limits and memory_limits_mb need one entry per observability container: loki, alloy, grafana, prometheus, cadvisor, node-exporter."
  }

  validation {
    condition     = var.logging.loki_retention_days >= 1 && var.logging.system_retention_days >= 1 && var.logging.system_retention_days <= var.logging.loki_retention_days
    error_message = "retention must be at least 1 day, and the system streams (journald, nginx) cannot be kept longer than loki_retention_days."
  }

  validation {
    condition     = alltrue([for c in var.logging.allowed_cidrs : can(cidrhost(c, 0))])
    error_message = "logging.allowed_cidrs entries must be IPv4 CIDRs, e.g. \"10.0.0.0/16\" or \"203.0.113.7/32\"."
  }

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.logging.grafana_subdomain))
    error_message = "grafana_subdomain must be a single DNS label (lowercase letters, digits and dashes)."
  }
}

variable "manage_default_security_group" {
  description = "Strip the VPC default security group to deny-all. false when the adopted VPC's default SG still carries live traffic."
  type        = bool
  default     = true
}
