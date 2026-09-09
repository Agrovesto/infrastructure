variable "name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "client_security_group_ids" {
  type = map(string)
}
variable "kms_key_arn" {
  type = string
}
variable "permissions_boundary_arn" {
  type = string
}
variable "backup_bucket_arn" {
  type = string
}
variable "alerts_topic_arn" {
  type = string
}
variable "log_retention_days" {
  type = number
}
variable "instance_class" {
  type    = string
  default = "db.m6i.large"
}
variable "engine_version" {
  description = "Exact SQL Server 2022 RDS build. Null selects the AWS default within the 16.0 parameter family; pin the resolved version before live production."
  type        = string
  default     = null
  validation {
    condition     = var.engine_version == null ? true : can(regex("^16\\.00\\.", var.engine_version))
    error_message = "Use a supported, exact SQL Server 2022 (16.00.*) RDS engine version."
  }
}
variable "allocated_storage" {
  type    = number
  default = 100
}
variable "max_allocated_storage" {
  type    = number
  default = 1000
}
variable "final_snapshot_identifier" {
  type = string
}

variable "identifier" {
  description = "Optional instance identifier override, useful when adopting a separately restored RDS instance."
  type        = string
  default     = null
}

