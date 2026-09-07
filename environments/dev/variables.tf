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
    condition     = var.permissions_boundary_arn == "arn:aws:iam::${var.account_id}:policy/${var.project}-bootstrap-dev-workload-boundary"
    error_message = "Use the workload boundary output from this account's dev bootstrap."
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
  default = 200
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
  default = "10.10.0.0/16"
}
variable "ecr_repositories" {
  description = "Repository suffixes. The same names are created in both accounts; only pull is shared. Include sql-admin in prod."
  type        = set(string)
  default     = ["api", "web", "sql-admin"]
  validation {
    condition     = length(var.ecr_repositories) > 0 && alltrue([for name in var.ecr_repositories : can(regex("^[a-z][a-z0-9._-]{0,39}$", name))])
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
    image        = string
    port         = optional(number, 8080)
    hostname     = string
    priority     = number
    health_path  = optional(string, "/health")
    database_key = optional(string)
    environment  = optional(map(string), {})
    secrets      = optional(map(string), {})
    user         = optional(string, "10001:10001")
    host_port    = number
    memory_mb    = optional(number, 512)
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
      can(regex("(@sha256:[a-f0-9]{64}|:[A-Za-z0-9][A-Za-z0-9_.-]{0,127})$", s.image)) && !endswith(s.image, ":latest") &&
      can(regex("/(${join("|", var.ecr_repositories)})(:|@)", s.image))
    ])
    error_message = "Use declared project ECR repositories in dev/prod, with an immutable release tag or digest. Never use latest."
  }
  validation {
    condition = alltrue([for s in values(var.services) :
      length(setintersection(toset(keys(s.environment)), toset(keys(s.secrets)))) == 0 &&
      alltrue([for k, v in s.environment : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k)) && !can(regex("(?i)(password|token|secret|private_key)", k))]) &&
      alltrue([for k, v in s.secrets : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k)) && startswith(v, "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:") && !startswith(v, "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.project}/dev/sql/") && !startswith(v, "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:rds!")]) &&
      (s.database_key == null ? true : length(setintersection(toset(concat(keys(s.environment), keys(s.secrets))), toset(["DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD", "DB_ENCRYPT", "DB_TRUST_SERVER_CERTIFICATE"]))) == 0)
    ])
    error_message = "Put secrets in same-account Secrets Manager ARNs, not plaintext environment values. Do not duplicate keys, override DB_* variables, or add managed SQL/admin secrets through the extra-secrets map."
  }
  validation {
    condition     = alltrue([for s in values(var.services) : s.host_port >= 1024 && s.host_port <= 65535 && s.host_port != 1433 && s.host_port == floor(s.host_port) && s.memory_mb >= 128]) && length(distinct([for s in values(var.services) : s.host_port])) == length(var.services)
    error_message = "Dev host ports must be unique, not 1433, and between 1024 and 65535; reserve at least 128 MiB per API."
  }
}
variable "enable_waf" {
  type    = bool
  default = false
}
variable "accept_sqlserver_eula" {
  description = "Must be explicitly true after accepting the Microsoft SQL Server EULA. Developer edition is NON-PRODUCTION ONLY."
  type        = bool
  default     = false
}
variable "instance_type" {
  type    = string
  default = "t3.large"
  validation {
    condition     = contains(["t3.large", "t3.xlarge", "t3.2xlarge", "m6i.large", "m6i.xlarge", "m6i.2xlarge", "m7i.large", "m7i.xlarge"], var.instance_type)
    error_message = "Use a supported x86-64 instance with at least 8 GiB RAM (SQL Server Linux does not support Graviton)."
  }
}
variable "ami_id" {
  description = "Optional tested x86-64 Amazon Linux 2023 AMI. AMI changes require an explicit maintenance replacement."
  type        = string
  default     = null
}
variable "root_volume_size" {
  type    = number
  default = 50
  validation {
    condition     = var.root_volume_size >= 30
    error_message = "Allocate at least 30 GiB for the OS, Docker and API images."
  }
}
variable "database_volume_size" {
  type    = number
  default = 100
  validation {
    condition     = var.database_volume_size >= 50
    error_message = "Allocate at least 50 GiB; native backup staging shares this disk and needs extra free space."
  }
}
variable "sqlserver_image" {
  type    = string
  default = "mcr.microsoft.com/mssql/server:2022-CU20-ubuntu-22.04"
  validation {
    condition     = startswith(var.sqlserver_image, "mcr.microsoft.com/mssql/server") && !endswith(var.sqlserver_image, ":latest") && !endswith(var.sqlserver_image, ":2022-latest")
    error_message = "Use a tested SQL Server 2022 x86-64 CU tag/digest including /opt/mssql-tools18; never a floating latest tag."
  }
}
variable "frontends" {
  type = map(object({
    branch_name           = optional(string, "dev")
    domain_prefix         = optional(string)
    environment_variables = optional(map(string), {})
    spa                   = optional(bool, true)
  }))
  default = {}
  validation {
    condition = alltrue([for name, app in var.frontends :
      can(regex("^[a-z][a-z0-9-]{0,23}$", name)) &&
      (app.domain_prefix == null ? true : (
        (app.domain_prefix == "" || can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", app.domain_prefix))) &&
        !contains([for s in values(var.services) : s.hostname], app.domain_prefix)
      ))
    ]) && length(distinct([for f in values(var.frontends) : f.domain_prefix if f.domain_prefix != null])) == length([for f in values(var.frontends) : f.domain_prefix if f.domain_prefix != null])
    error_message = "Frontend custom domain prefixes must be valid, unique and not collide with API hostnames. Null uses only the Amplify-provided domain."
  }
}
