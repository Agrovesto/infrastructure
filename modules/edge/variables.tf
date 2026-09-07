variable "name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "public_subnet_ids" {
  type = list(string)
}
variable "certificate_arn" {
  type = string
}
variable "access_log_bucket" {
  type = string
}
variable "kms_key_arn" {
  type = string
}
variable "alerts_topic_arn" {
  type = string
}
variable "log_retention_days" {
  type = number
}
variable "enable_waf" {
  type = bool
}
