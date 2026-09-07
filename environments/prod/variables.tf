variable "project" {
  type    = string
  default = "agrovesto"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,15}$", var.project))
    error_message = "Use a 3-16 character lowercase project slug."
  }
}
variable "account_id" {
  description = "The account this environment is allowed to modify. Provider, backend and CI all verify it."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "An AWS account ID contains exactly 12 digits."
  }
}
variable "peer_account_id" {
  description = "The other environment's AWS account, granted ECR pull access only."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.peer_account_id)) && var.peer_account_id != var.account_id
    error_message = "Dev and prod MUST have different valid AWS account IDs."
  }
}
variable "aws_region" {
  type    = string
  default = "eu-west-1"
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "Use a commercial AWS region with Amplify and RDS SQL Server availability."
  }
}
variable "availability_zones" {
  type    = list(string)
  default = ["eu-west-1a", "eu-west-1b"]
  validation {
    condition = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2 && alltrue([
      for az in var.availability_zones : startswith(az, var.aws_region)
    ])
    error_message = "Set two different availability zones in aws_region."
  }
}
variable "permissions_boundary_arn" {
  type = string
  validation {
    condition     = var.permissions_boundary_arn == "arn:aws:iam::${var.account_id}:policy/${var.project}-bootstrap-prod-workload-boundary"
    error_message = "Use the workload boundary output from this account's prod bootstrap."
  }
}
variable "zone_name" {
  description = "Public hosted zone, e.g. dev.example.com in dev and example.com in prod. No trailing dot."
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.zone_name))
    error_message = "Provide a lowercase DNS zone without a trailing dot or wildcard."
  }
}
variable "existing_zone_id" {
  description = "Null creates (or allows importing) a managed zone. Set an ID to use a zone without taking ownership."
  type        = string
  default     = null
}
variable "dns_records" {
  type    = map(object({ name = string, type = string, ttl = optional(number, 300), records = list(string) }))
  default = {}
}
variable "dns_aliases" {
  type    = map(object({ name = string, type = optional(string, "A"), target_name = string, target_zone_id = string, evaluate_target_health = optional(bool, false) }))
  default = {}
}
variable "alert_emails" {
  type = set(string)
  validation {
    condition     = length(var.alert_emails) > 0 && length(var.alert_emails) <= 10 && alltrue([for email in var.alert_emails : can(regex("^[^ @]+@[^ @]+\\.[^ @]+$", email))])
    error_message = "Supply 1-10 valid operational/budget email addresses and confirm their SNS subscriptions."
  }
}
variable "monthly_budget_usd" {
  type    = number
  default = 1500
  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "The monthly USD alert threshold must be positive; it is not a spending cap."
  }
}
variable "log_retention_days" {
  type    = number
  default = 365
  validation {
    condition     = contains([30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "Choose a supported CloudWatch retention period of at least 30 days."
  }
}
variable "enable_guardduty" {
  description = "Set false if GuardDuty is already centrally managed in this account/region, or import its detector."
  type        = bool
  default     = true
}
variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}
variable "ecr_repositories" {
  description = "Repository suffixes. The same names are created in both accounts; only pull is shared. Include sql-admin in prod."
  type        = set(string)
  default     = ["api", "web", "sql-admin"]
  validation {
    condition     = contains(var.ecr_repositories, "sql-admin") && alltrue([for name in var.ecr_repositories : can(regex("^[a-z][a-z0-9._-]{0,39}$", name))])
    error_message = "Provide one or more lowercase repository names without a slash."
  }
}
variable "databases" {
  description = "Stable key => SQL Server database name. Terraform manages secret metadata; the private SQL provisioning program creates databases/logins."
  type        = map(string)
  validation {
    condition = length(var.databases) > 0 && length(var.databases) <= 50 && alltrue([for key, name in var.databases :
      key != "admin" && can(regex("^[a-z][a-z0-9_]{0,29}$", key)) && can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", name)) && !contains(["master", "model", "msdb", "tempdb", "rdsadmin"], lower(name))
    ]) && length(distinct([for name in values(var.databases) : lower(name)])) == length(var.databases)
    error_message = "Supply 1-50 unique non-system databases; use SQL identifiers and lowercase keys (not admin). Renames require a database migration."
  }
}
variable "services_enabled" {
  description = "False for the first scaffold deployment. Enable only after image publication and SQL initialization. Turning off prod destroys ECS services, NOT databases."
  type        = bool
  default     = false
}

variable "services" {
  type = map(object({
    image                = string
    port                 = optional(number, 8080)
    hostname             = string
    priority             = number
    health_path          = optional(string, "/health")
    database_key         = optional(string)
    environment          = optional(map(string), {})
    secrets              = optional(map(string), {})
    user                 = optional(string, "10001:10001")
    cpu                  = optional(number, 256)
    memory               = optional(number, 512)
    min_count            = optional(number, 2)
    max_count            = optional(number, 4)
    health_check_command = optional(list(string), [])
  }))
  default = {}
  validation {
    condition = alltrue([for name, s in var.services :
      can(regex("^[a-z][a-z0-9-]{0,23}$", name)) && name != "mssql" && name != "sql-admin" &&
      (s.hostname == "" || can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", s.hostname))) &&
      s.port >= 1024 && s.port <= 65535 && s.port == floor(s.port) &&
      s.priority >= 1 && s.priority <= 50000 && s.priority == floor(s.priority) && startswith(s.health_path, "/") &&
      (s.database_key == null ? true : contains(keys(var.databases), s.database_key)) &&
      can(regex("^[1-9][0-9]*(:[0-9]+)?$", s.user))
    ]) && length(distinct([for s in values(var.services) : s.hostname])) == length(var.services) && length(distinct([for s in values(var.services) : s.priority])) == length(var.services)
    error_message = "Service names/hostnames must be valid and unique, listener priorities unique, users non-root, ports 1024-65535 and database keys declared."
  }
  validation {
    condition = alltrue([for s in values(var.services) :
      (startswith(s.image, "${var.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project}/") || startswith(s.image, "${var.peer_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project}/")) &&
      can(regex("@sha256:[a-f0-9]{64}$", s.image)) &&
      can(regex("/(${join("|", var.ecr_repositories)})(:|@)", s.image))
    ])
    error_message = "Use declared project ECR repositories in dev/prod, with a pinned sha256 image digest. Never use latest."
  }
  validation {
    condition = alltrue([for s in values(var.services) :
      length(setintersection(toset(keys(s.environment)), toset(keys(s.secrets)))) == 0 &&
      alltrue([for k, v in s.environment : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k)) && !can(regex("(?i)(password|token|secret|private_key)", k))]) &&
      alltrue([for k, v in s.secrets : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k)) && startswith(v, "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:") && !startswith(v, "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.project}/prod/sql/") && !startswith(v, "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:rds!")]) &&
      (s.database_key == null ? true : length(setintersection(toset(concat(keys(s.environment), keys(s.secrets))), toset(["DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD", "DB_ENCRYPT", "DB_TRUST_SERVER_CERTIFICATE"]))) == 0)
    ])
    error_message = "Put secrets in same-account Secrets Manager ARNs, not plaintext environment values. Do not duplicate keys, override DB_* variables, or add managed SQL/admin secrets through the extra-secrets map."
  }
  validation {
    condition = alltrue([for s in values(var.services) :
      contains(try({ "256" = [512, 1024, 2048], "512" = [1024, 2048, 3072, 4096], "1024" = [2048, 3072, 4096, 5120, 6144, 7168, 8192], "2048" = range(4096, 16385, 1024), "4096" = range(8192, 30721, 1024) }[tostring(s.cpu)], []), s.memory) &&
      s.min_count >= 2 && s.max_count >= s.min_count && s.min_count == floor(s.min_count) && s.max_count == floor(s.max_count) &&
      (length(s.health_check_command) == 0 ? true : contains(["CMD", "CMD-SHELL"], s.health_check_command[0]))
    ])
    error_message = "Use valid Fargate CPU/memory pairs, at least two prod tasks, max_count >= min_count, and ECS-formatted health check commands."
  }
}
variable "sql_admin_image" {
  description = "Scanned SQL admin image built from ops/sql-admin/Dockerfile. Null creates a not-yet-published :bootstrap reference for the first scaffold only."
  type        = string
  default     = null
  validation {
    condition = var.sql_admin_image == null ? !var.services_enabled : (
      (startswith(var.sql_admin_image, "${var.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project}/sql-admin@sha256:") || startswith(var.sql_admin_image, "${var.peer_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project}/sql-admin@sha256:")) && can(regex("@sha256:[a-f0-9]{64}$", var.sql_admin_image))
    )
    error_message = "Set sql_admin_image to a scanned, pinned ECR sql-admin digest before enabling prod services."
  }
}
variable "rds_instance_class" {
  type    = string
  default = "db.m6i.large"
}
variable "rds_engine_version" {
  type    = string
  default = null
}
variable "rds_allocated_storage" {
  type    = number
  default = 100
}
variable "rds_max_allocated_storage" {
  type    = number
  default = 1000
}
variable "rds_final_snapshot_identifier" {
  description = "Must be unique in the account at destruction time; deliberately change before an approved final deletion."
  type        = string
  default     = "agrovesto-prod-sqlserver-final-retained"
}

variable "rds_identifier" {
  description = "Null uses the standard project-prod-sqlserver name. Override only for an approved creation/recovery; changing a live managed identifier needs review."
  type        = string
  default     = null
}
