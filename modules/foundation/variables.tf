variable "name" {
  type = string
}
variable "project" {
  type = string
}
variable "environment" {
  type = string
}
variable "account_id" {
  type = string
}
variable "region" {
  type = string
}
variable "permissions_boundary_arn" {
  type = string
}
variable "alert_emails" {
  type = set(string)
}
variable "monthly_budget_usd" {
  type = number
}
variable "log_retention_days" {
  type = number
}
variable "enable_guardduty" {
  type    = bool
  default = true
}
