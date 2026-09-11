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
  default = "t3.xlarge"
}

variable "ami_id" {
  description = "Leave empty to use the latest Amazon Linux 2023 AMI"
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
