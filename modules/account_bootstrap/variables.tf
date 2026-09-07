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
variable "github_repository" {
  type = string
}
variable "existing_oidc_provider_arn" {
  type    = string
  default = null
}
variable "github_oidc_subject" {
  description = "Optional exact subject for repositories using immutable repo/owner IDs. Must preserve environment, ref, push event and workflow restrictions."
  type        = string
  default     = null
  validation {
    condition = var.github_oidc_subject == null ? true : (
      strcontains(var.github_oidc_subject, ":environment:${var.environment}:ref:refs/heads/${var.environment}:event_name:push:workflow_ref:${var.github_repository}/.github/workflows/infrastructure.yml@refs/heads/${var.environment}")
    )
    error_message = "An override must retain the exact environment, branch, push event and infrastructure workflow restrictions."
  }
}
variable "bootstrap_zone_name" {
  description = "Optional NEW public zone created during human account bootstrap. Environment stacks then reference its ID, rather than owning this zone twice."
  type        = string
  default     = null
}
