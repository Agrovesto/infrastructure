variable "name" {
  type = string
}
variable "project" {
  type = string
}
variable "region" {
  type = string
}
variable "account_id" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "subnet_id" {
  type = string
}
variable "availability_zone" {
  type = string
}
variable "kms_key_arn" {
  type = string
}
variable "permissions_boundary_arn" {
  type = string
}
variable "access_log_bucket" {
  type = string
}
variable "alerts_topic_arn" {
  type = string
}
variable "log_retention_days" {
  type = number
}
variable "alb_security_group_id" {
  type = string
}
variable "https_listener_arn" {
  type = string
}
variable "alb_dns_name" {
  type = string
}
variable "alb_zone_id" {
  type = string
}
variable "alb_arn_suffix" {
  type = string
}
variable "zone_id" {
  type = string
}
variable "zone_name" {
  type = string
}
variable "ecr_repository_arns" {
  type = set(string)
}
variable "databases" {
  type = map(string)
}
variable "database_secret_arns" {
  type = map(string)
}
variable "services_enabled" {
  type = bool
}
variable "services" {
  type = map(object({
    image        = string
    port         = optional(number, 8080)
    host_port    = number
    hostname     = string
    priority     = number
    health_path  = optional(string, "/health")
    database_key = optional(string)
    environment  = optional(map(string), {})
    secrets      = optional(map(string), {})
    memory_mb    = optional(number, 512)
    user         = optional(string, "10001:10001")
  }))
}
variable "instance_type" {
  type    = string
  default = "t3.large"
}
variable "ami_id" {
  type    = string
  default = null
}
variable "root_volume_size" {
  type    = number
  default = 50
}
variable "database_volume_size" {
  type    = number
  default = 100
}
variable "sqlserver_image" {
  type    = string
  default = "mcr.microsoft.com/mssql/server:2022-CU20-ubuntu-22.04"
}
variable "accept_sqlserver_eula" {
  type = bool
}
