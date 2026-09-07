variable "name" {
  type = string
}
variable "region" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "kms_key_arn" {
  type = string
}
variable "permissions_boundary_arn" {
  type = string
}
variable "log_retention_days" {
  type = number
}
variable "alerts_topic_arn" {
  type = string
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
variable "database_host" {
  type = string
}
variable "database_security_group_id" {
  type = string
}
variable "database_master_secret_arn" {
  type = string
}
variable "databases" {
  type = map(string)
}
variable "database_secret_arns" {
  type = map(string)
}
variable "sql_admin_image" {
  type = string
}
variable "services_enabled" {
  description = "False scaffolds task definitions, networking and DNS without starting services."
  type        = bool
}
variable "services" {
  type = map(object({
    image                = string
    port                 = optional(number, 8080)
    hostname             = string
    priority             = number
    health_path          = optional(string, "/health")
    health_check_command = optional(list(string), [])
    database_key         = optional(string)
    cpu                  = optional(number, 256)
    memory               = optional(number, 512)
    min_count            = optional(number, 2)
    max_count            = optional(number, 4)
    environment          = optional(map(string), {})
    secrets              = optional(map(string), {})
    user                 = optional(string, "10001:10001")
  }))
}
