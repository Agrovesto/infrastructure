variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project" {
  type    = string
  default = "agrovesto"
}

variable "domain_name" {
  description = "Root domain for all apps (frontends + backends)"
  type        = string
}

variable "create_hosted_zone" {
  type    = bool
  default = true
}

variable "existing_zone_id" {
  type    = string
  default = ""
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.1.0/24"]
}

variable "allowed_ssh_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "instance_type" {
  type    = string
  default = "t3.xlarge"
}

variable "key_name" {
  type    = string
  default = ""
}

variable "root_volume_size_gb" {
  type    = number
  default = 50
}

variable "mssql_volume_size_gb" {
  type    = number
  default = 100
}

variable "github_access_token" {
  type      = string
  default   = ""
  sensitive = true
}

variable "amplify_apps" {
  description = "Amplify frontends. Add another map key to create a new app."
  type = map(object({
    repository            = string
    branch                = optional(string, "main")
    subdomain             = string
    framework             = optional(string, "React")
    environment_variables = optional(map(string), {})
  }))
}

variable "apis" {
  description = "Backend APIs on the EC2 docker host. Add a key to launch another API."
  type = map(object({
    image     = string
    host_port = number
    subdomain = string
    env       = optional(map(string), {})
  }))
}

variable "mssql_sa_password" {
  type      = string
  sensitive = true
}

variable "mssql_databases" {
  description = "Databases created on the single MSSQL instance"
  type        = list(string)
}

variable "mssql_image" {
  type    = string
  default = "mcr.microsoft.com/mssql/server:2022-latest"
}

variable "scheduler_timezone" {
  type    = string
  default = "Africa/Lagos"
}

variable "ec2_start_cron" {
  type    = string
  default = "cron(0 8 ? * MON-FRI *)"
}

variable "ec2_stop_cron" {
  type    = string
  default = "cron(0 20 ? * MON-FRI *)"
}

variable "enable_ec2_scheduler" {
  type    = bool
  default = true
}

variable "backup_retention_days" {
  type    = number
  default = 14
}
