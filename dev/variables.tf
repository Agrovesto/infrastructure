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
  default     = []
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
    # Serve this API's vhost over HTTPS at the Caddy TLS edge (port 80 redirects
    # to https with 308). Off — the default — keeps the vhost on plain HTTP
    # through the edge's :80 catch-all, which is the current behaviour of every
    # dev API host. nginx keeps routing the vhost either way.
    tls_via_caddy = optional(bool, false)
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
    image        = optional(string, "hashicorp/vault:1.15")
    host_port    = optional(number, 8200)
    subdomain    = optional(string, "vault")
    oidc_enabled = optional(bool, false) # opt-in: requires three OAuth credentials and a planned Vault restart
  })
  default = {
    image     = "hashicorp/vault:1.15"
    host_port = 8200
    subdomain = "vault"
  }
}

# Prepare a dedicated AWS KMS key and grant the EC2 instance role permission
# to use it. Does NOT change the running Vault configuration or restart Vault.
# A one-time operator-led Shamir -> awskms seal migration is required; see
# docs/vault-auto-unseal.md. Keep this off until backup/key custody is agreed.
variable "prepare_vault_kms_auto_unseal" {
  description = "Provision dedicated AWS KMS key and EC2 role grants for a manual Vault seal migration; does not enable the seal on the host"
  type        = bool
  default     = false
}

# GitHub browser login uses Dex (GitHub OAuth -> OIDC -> Vault), NOT the Vault
# GitHub PAT auth method. Set these as CI secrets, never in tfvars or source.
variable "vault_github_client_id" {
  type    = string
  default = ""
}

variable "vault_github_client_secret" {
  type      = string
  sensitive = true
  default   = ""
}

variable "vault_oidc_client_secret" {
  description = "Independent random secret for the Vault <-> Dex OIDC client"
  type        = string
  sensitive   = true
  default     = ""
}

# An OIDC apply changes the live Vault service's Compose definition and will
# restart it. The operator must verify a root-volume backup and the CURRENT
# seal's restart procedure: three Shamir shares before migration, or a tested
# KMS auto-unseal after migration (with the recovery shares still in custody).
variable "vault_oidc_restart_ack" {
  description = "Explicit acknowledgement of Vault restart, root-volume backup, and readiness to unseal under the current seal"
  type        = bool
  default     = false
}

variable "vault_github_organization" {
  type    = string
  default = "Agrovesto"
}

variable "vault_github_team_slug" {
  description = "Only members of this GitHub team receive the scoped Vault KV operator policy"
  type        = string
  default     = "infrastructure"
}

# -----------------------------------------------------------------------------
# Redis (shared cache for the APIs on the host)
# -----------------------------------------------------------------------------

variable "redis" {
  description = <<-EOT
    Redis on the dev EC2 docker host. Every API container reaches it as
    redis:6379 over the compose network; the published port is loopback-only and
    the security group has no ingress for it, so reaching it from a laptop is an
    SSH tunnel (`redis_access` output prints the command).

    Cache semantics by default: no password, no persistence, allkeys-lru eviction
    at maxmemory_mb. That is deliberate — the box already runs SQL Server, so a
    cache that grows without bound is what takes the APIs down. Flip
    persistence = true when an API needs queues or sessions to survive a restart.
  EOT

  type = object({
    enabled   = optional(bool, true)
    image     = optional(string, "redis:8.8-alpine")
    host_port = optional(number, 6379)

    # Off by default: the port is loopback-only and the compose network is
    # private to this host, so a password would only protect it from the APIs
    # themselves. Turn it on the moment Redis is reachable from anywhere else,
    # and add REDIS_PASSWORD to the API env at the same time.
    password = optional(string, "") # ggignore - empty means no AUTH; override via TF_VAR_redis

    # Eviction, not growth: maxmemory is the reason this container cannot eat
    # SQL Server's memory. allkeys-lru suits a cache; use noeviction for queues.
    maxmemory_mb     = optional(number, 256)
    maxmemory_policy = optional(string, "allkeys-lru")

    # RDB + AOF into a bind mount on the root disk. Costs a restart-time rewrite
    # and is off because a dev cache is allowed to be empty after a reboot.
    persistence = optional(bool, false)
    data_dir    = optional(string, "/data/redis")

    cpu_limit       = optional(string, "0.25")
    memory_limit_mb = optional(number, 384)
  })

  default = {}

  validation {
    condition     = contains(["allkeys-lru", "allkeys-lfu", "volatile-lru", "volatile-lfu", "volatile-ttl", "allkeys-random", "volatile-random", "noeviction"], var.redis.maxmemory_policy)
    error_message = "redis.maxmemory_policy must be one of Redis' eviction policies (allkeys-lru, volatile-lru, noeviction, ...)."
  }

  validation {
    condition     = var.redis.maxmemory_mb > 0 && var.redis.memory_limit_mb > var.redis.maxmemory_mb
    error_message = "redis.memory_limit_mb must exceed maxmemory_mb: Redis needs room for replication buffers and fragmentation on top of the dataset."
  }
}

# -----------------------------------------------------------------------------
# SonarQube (code quality, backed by the on-host SQL Server)
# -----------------------------------------------------------------------------

variable "sonarqube" {
  description = <<-EOT
    SonarQube Community Build on the dev EC2 docker host, using the SQL Server
    container that is already on this box. This is the server the CI pipelines
    push to via SONAR_HOST_URL / SONAR_TOKEN (see .github/workflows and
    run-sonar.sh); the sonar-project-*.properties files in the repo root point
    at it.

    Two SonarSource requirements drive the database settings below and are not
    negotiable, so they are pinned rather than free-form:
      * collation MUST be case- AND accent-sensitive (CS_AS). The SQL Server
        default here is case-insensitive, so the sonar database is created with
        an explicit COLLATE (see local.init_sql).
      * READ_COMMITTED_SNAPSHOT must be ON, or analyses deadlock under load.

    Resource caps are small on purpose: SonarSource's own guidance is 4 GB of
    RAM for a small installation, and this host is a t3.large (8 GiB) that also
    runs SQL Server, seven APIs and the logging stack. See README for the
    trade-off; raise instance_type before raising these numbers.
  EOT

  type = object({
    enabled   = optional(bool, true)
    image     = optional(string, "sonarqube:26.9.0.129388-community")
    host_port = optional(number, 9000)
    subdomain = optional(string, "sonar")

    # --- database -----------------------------------------------------------
    # Added to local.mssql_all_databases automatically, so it is both created by
    # init-dbs.sql and included in the nightly backup loop without being listed
    # in var.mssql_databases as well (listing it there is harmless: the union is
    # deduplicated).
    # "postgres" runs a dedicated postgres container (sonarqube-db) for
    # SonarQube, with its data on the SonarQube EBS volume; "mssql" uses the
    # shared SQL Server container. Postgres is SonarSource's recommended engine
    # and the only way to restore a pg_dump from an existing SonarQube.
    database_engine    = optional(string, "mssql")
    postgres_image     = optional(string, "postgres:17-alpine")
    database_name      = optional(string, "sonar")
    database_collation = optional(string, "SQL_Latin1_General_CP1_CS_AS")

    # A login of its own rather than `sa`: SonarQube only ever touches one
    # database, so it should not hold sysadmin over the other five. The password
    # travels into the container through .env and into CREATE LOGIN as a sqlcmd
    # variable, so it never lands in the S3 config bucket.
    #
    # CHECK_POLICY is left on, so an override has to satisfy Windows complexity
    # (three of upper/lower/digit/symbol) and must not contain the login name —
    # both are enforced by SQL Server, not by Terraform.
    database_username      = optional(string, "sonarqube")
    database_password      = optional(string, "Agrovesto-Dev-Quality-2026") # ggignore - dev-only default, override via TF_VAR_sonarqube
    jdbc_encrypt           = optional(string, "true")
    jdbc_trust_server_cert = optional(bool, true)

    # --- JVM heaps ----------------------------------------------------------
    # The three SonarQube processes, each capped. SonarSource suggests giving
    # Elasticsearch half of available RAM; on this host that is not an option,
    # so Elasticsearch gets 1 GB and analyses of anything large will be slow.
    es_java_opts  = optional(string, "-Xms512m -Xmx1g")
    web_java_opts = optional(string, "-Xms256m -Xmx512m")
    ce_java_opts  = optional(string, "-Xms256m -Xmx512m")

    # --- caps ---------------------------------------------------------------
    # memory_limit_mb is what keeps a heavy analysis from OOM-killing SQL Server:
    # the cgroup kills this container instead of the kernel picking a victim.
    cpu_limit       = optional(string, "1.00")
    memory_limit_mb = optional(number, 3072)

    # --- host kernel limits --------------------------------------------------
    # Elasticsearch fails a bootstrap check and refuses to start unless the host
    # can map this many virtual memory areas; Ubuntu's default is 65530. These
    # are written to /etc/sysctl.d by user_data, so they are host-wide — there is
    # no per-container vm.max_map_count.
    vm_max_map_count = optional(number, 262144)
    fs_file_max      = optional(number, 131072)

    # --- storage ------------------------------------------------------------
    # Elasticsearch's indices are I/O heavy and worth 20-30 GB over time, so
    # they get a volume of their own rather than the root disk, and that volume
    # is not delete_on_termination: replacing the instance keeps the analyses.
    volume_size_gb = optional(number, 20)
    volume_device  = optional(string, "/dev/sdh")
    data_dir       = optional(string, "/data/sonarqube")

    # --- reaching the UI -----------------------------------------------------
    expose_via_nginx = optional(bool, true)
    # Public scheme when GitHub SSO is not configured. A complete set of
    # sonarqube_github_* credentials adds a Caddy TLS edge and deliberately
    # overrides this to https, because SonarSource rejects HTTP GitHub callbacks.
    scheme = optional(string, "http")
    # Same shape as logging.allowed_cidrs: empty means 127.0.0.1, i.e. the vhost
    # answers an SSH tunnel and nobody else. Note that this also decides whether
    # the GitHub Actions scanner can reach the server — see terraform.auto.tfvars.
    allowed_cidrs = optional(list(string), [])
  })

  default = {}

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.sonarqube.subdomain))
    error_message = "sonarqube.subdomain must be a single DNS label (lowercase letters, digits and dashes)."
  }

  validation {
    condition     = contains(["mssql", "postgres"], var.sonarqube.database_engine)
    error_message = "sonarqube.database_engine must be \"mssql\" or \"postgres\"."
  }

  validation {
    condition     = contains(["http", "https"], var.sonarqube.scheme)
    error_message = "sonarqube.scheme must be \"http\" or \"https\"."
  }

  validation {
    condition     = var.sonarqube.vm_max_map_count >= 262144
    error_message = "sonarqube.vm_max_map_count must be at least 262144: below that Elasticsearch fails its bootstrap check and SonarQube never starts."
  }

  validation {
    condition     = can(regex("_CS_AS$", var.sonarqube.database_collation))
    error_message = "sonarqube.database_collation must be case-sensitive AND accent-sensitive (ending in _CS_AS); SonarQube fails to start otherwise."
  }

  validation {
    condition     = alltrue([for c in var.sonarqube.allowed_cidrs : can(cidrhost(c, 0))])
    error_message = "sonarqube.allowed_cidrs entries must be IPv4 CIDRs, e.g. \"10.0.0.0/16\" or \"203.0.113.7/32\"."
  }

  # CHECK_POLICY is left on for this login, so SQL Server itself rejects a weak
  # password — but it rejects it at boot, inside a container, on a box that is
  # stopped every evening. Failing at plan time instead is much cheaper to debug.
  validation {
    condition = !var.sonarqube.enabled || (
      length(var.sonarqube.database_password) >= 12 &&
      can(regex("[A-Z]", var.sonarqube.database_password)) &&
      can(regex("[a-z]", var.sonarqube.database_password)) &&
      can(regex("[0-9]", var.sonarqube.database_password)) &&
      !can(regex("(?i)${var.sonarqube.database_username}", var.sonarqube.database_password))
    )
    error_message = "sonarqube.database_password must be >=12 characters with an uppercase letter, a lowercase letter and a digit, and must not contain the login name (SQL Server's CHECK_POLICY enforces all of this and will otherwise reject CREATE LOGIN at boot)."
  }

  # The password is substituted literally into init-dbs.sql by `sqlcmd -v`, so a
  # quote in it would terminate the SQL string and turn the rest of the script
  # into a syntax error at best.
  validation {
    condition     = !can(regex("['\"]", var.sonarqube.database_password))
    error_message = "sonarqube.database_password must not contain a single or double quote: it is substituted literally into init-dbs.sql."
  }
}

# GitHub App credentials for SonarQube login. They stay separate from the
# sonarqube object so the secret values can be marked sensitive and supplied by
# CI without making the whole (widely-rendered) object sensitive. Leaving all
# four empty keeps GitHub login disabled and preserves the normal local login.
# Supplying any of them requires supplying all four; the app registration and
# callback URL are documented in docs/github-sso.md.
variable "sonarqube_github_client_id" {
  description = "Client ID of the GitHub App used for SonarQube authentication; empty disables GitHub SSO"
  type        = string
  default     = ""
}

variable "sonarqube_github_client_secret" {
  description = "Client secret of the GitHub App used for SonarQube authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sonarqube_github_app_id" {
  description = "Numeric App ID of the GitHub App used for SonarQube authentication"
  type        = string
  default     = ""
}

variable "sonarqube_github_private_key" {
  description = "PEM private key of the GitHub App used for SonarQube authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sonarqube_github_organizations" {
  description = "GitHub organizations whose members may log in to SonarQube"
  type        = list(string)
  default     = ["Agrovesto"]

  validation {
    condition     = length(var.sonarqube_github_organizations) > 0 && alltrue([for org in var.sonarqube_github_organizations : can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", org))])
    error_message = "sonarqube_github_organizations must contain at least one valid GitHub organization login."
  }
}

variable "sonarqube_github_allow_sign_up" {
  description = "Allow an authorized GitHub organization member to be created in SonarQube on first login"
  type        = bool
  default     = true
}

variable "sonarqube_github_synchronize_groups" {
  description = "Synchronize GitHub teams to existing SonarQube groups named Organization/Team"
  type        = bool
  default     = true
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
    repository            = optional(string) # null creates a manual Amplify placeholder until a repo is ready
    branch                = optional(string, "main")
    subdomain             = string
    framework             = optional(string, "React")
    build_spec            = optional(string)
    environment_variables = optional(map(string), {})
    enable_auto_build     = optional(bool, true)
    publish_dns           = optional(bool, true) # keep unbuilt placeholders out of DNS
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
    alertmanager_image  = optional(string, "prom/alertmanager:v0.28.1")

    # Published on 127.0.0.1 on the host only, and the security group has no
    # ingress for any of them: this is an SSH-tunnel or nginx-only surface.
    loki_port          = optional(number, 3100)
    alloy_port         = optional(number, 12345)
    alloy_push_port    = optional(number, 3101)
    grafana_port       = optional(number, 3000)
    prometheus_port    = optional(number, 9090)
    cadvisor_port      = optional(number, 8080)
    node_exporter_port = optional(number, 9100)
    alertmanager_port  = optional(number, 9093)

    # --- reaching the UI ------------------------------------------------------
    expose_via_nginx  = optional(bool, true)
    grafana_subdomain = optional(string, "dev-grafana")

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
      alertmanager  = "0.10"
    })
    memory_limits_mb = optional(map(number), {
      loki          = 384
      alloy         = 192
      grafana       = 192
      prometheus    = 384
      cadvisor      = 128
      node-exporter = 48
      alertmanager  = 64
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

# The dev Grafana uses a GitHub OAuth App (not the GitHub App used by
# SonarQube). A GitHub OAuth App has one callback registration, so dev and prod
# Grafana deliberately have separate credentials. Both values empty means the
# existing local admin login is the only login method.
variable "grafana_github_client_id" {
  description = "Client ID of the GitHub OAuth App used by dev Grafana; empty disables GitHub SSO"
  type        = string
  default     = ""
}

variable "grafana_github_client_secret" {
  description = "Client secret of the GitHub OAuth App used by dev Grafana"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_github_organizations" {
  description = "GitHub organizations whose members may log in to dev Grafana"
  type        = list(string)
  default     = ["Agrovesto"]

  validation {
    condition     = length(var.grafana_github_organizations) > 0 && alltrue([for org in var.grafana_github_organizations : can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", org))])
    error_message = "grafana_github_organizations must contain at least one valid GitHub organization login."
  }
}

variable "grafana_github_allow_sign_up" {
  description = "Allow an authorized GitHub organization member to be created in dev Grafana on first login"
  type        = bool
  default     = true
}

variable "grafana_github_team_roles" {
  description = "GitHub team-to-Grafana role mappings; role evaluation always prioritizes Admin, then Editor, then Viewer"
  type = list(object({
    organization = optional(string, "Agrovesto")
    team_slug    = string
    role         = string
  }))
  default = [
    { team_slug = "infrastructure", role = "Admin" },
    { team_slug = "team-leads", role = "Editor" },
    { team_slug = "backend", role = "Viewer" },
    { team_slug = "frontend", role = "Viewer" },
    { team_slug = "mobile", role = "Viewer" },
  ]

  validation {
    condition = (
      length(var.grafana_github_team_roles) > 0 &&
      length(distinct([for binding in var.grafana_github_team_roles : lower("${binding.organization}/${binding.team_slug}")])) == length(var.grafana_github_team_roles) &&
      alltrue([
        for binding in var.grafana_github_team_roles :
        can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", binding.organization)) &&
        can(regex("^[a-z0-9]([a-z0-9-]{0,98}[a-z0-9])?$", binding.team_slug)) &&
        contains(["Viewer", "Editor", "Admin"], binding.role)
      ])
    )
    error_message = "grafana_github_team_roles must contain unique organization/team slugs and a Viewer, Editor, or Admin role."
  }
}

variable "manage_default_security_group" {
  description = "Strip the VPC default security group to deny-all. false when the adopted VPC's default SG still carries live traffic."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# SNS + alarms (sns.tf, alarms.tf)
# -----------------------------------------------------------------------------

variable "alert_emails" {
  description = "Emails subscribed to the alerts topic (each must confirm the AWS email)"
  type        = list(string)
  default     = []
}

variable "app_sns_topics" {
  description = "Application topics (<project>-<env>-<name>) the APIs on the host may publish to"
  type        = list(string)
  default     = ["notifications"]
}

variable "app_topic_emails" {
  description = "Emails subscribed to every app topic (optional)"
  type        = list(string)
  default     = []
}

variable "alarm_cpu_percent" {
  type    = number
  default = 85
}

variable "alert_rules" {
  description = "Thresholds for the dev host's Prometheus alert rules (Alertmanager -> SNS alerts topic)"
  type = object({
    cpu_percent       = optional(number, 90)
    memory_percent    = optional(number, 90)
    disk_free_percent = optional(number, 10)
  })
  default = {}
}

variable "rekognition" {
  description = "Amazon Rekognition: face collections (KYC), liveness guest pool and media retention"
  type = object({
    collections             = optional(list(string), ["customers"])
    liveness_identity_pool  = optional(bool, true)
    liveness_retention_days = optional(number, 30)
    upload_retention_days   = optional(number, 90)
  })
  default = {}
}

variable "import_existing" {
  description = "Enable the one-shot import blocks in imports.tf. terraform test sets false (mock providers cannot import)."
  type        = bool
  default     = true
}

variable "s3_access_log_retention_days" {
  description = "Days to keep S3 server access logs for the dev buckets"
  type        = number
  default     = 90
}