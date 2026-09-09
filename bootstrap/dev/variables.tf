variable "project" {
  type    = string
  default = "agrovesto"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,15}$", var.project))
    error_message = "Use a short lowercase project slug (3-16 characters)."
  }
}
variable "account_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Provide the target account's 12-digit AWS ID."
  }
}
variable "aws_region" {
  type    = string
  default = "eu-west-1"
}
variable "github_repository" {
  type    = string
  default = "Agrovesto/infrastructure"
}
variable "existing_oidc_provider_arn" {
  type    = string
  default = null
}
variable "github_oidc_subject" {
  type    = string
  default = null
}

variable "bootstrap_zone_name" {
  type    = string
  default = null
}
