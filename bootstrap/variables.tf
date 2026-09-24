# =============================================================================
# Variables — prod bootstrap
# =============================================================================

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project" {
  type    = string
  default = "agrovesto"
}

variable "environment" {
  description = "Environment being bootstrapped (this bootstrap only covers prod)"
  type        = string
  default     = "prod"
}

variable "state_bucket_name" {
  description = "Terraform state bucket. Empty = same convention as dev (nomaos-tfstate-<account-id>-<region>)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# GitHub Actions deploy role
# -----------------------------------------------------------------------------

variable "deploy_role_name" {
  type    = string
  default = "agrovesto-prod-github-deploy"
}

variable "github_sub_patterns" {
  description = "Allowed token.actions.githubusercontent.com:sub patterns for the deploy role (main + PRs; arena branches so pushes from working branches can assume the role during setup — tighten if you like)"
  type        = list(string)
  default = [
    "repo:Agrovesto@101108012/*:ref:refs/heads/main",
    "repo:Agrovesto@101108012/*:ref:refs/heads/arena/*",
    "repo:Agrovesto@101108012/*:pull_request"
  ]
}

variable "create_oidc_provider" {
  description = "false if token.actions.githubusercontent.com is already registered in the prod account (or import it: terraform import aws_iam_openid_connect_provider.github arn:aws:iam::<acct>:oidc-provider/token.actions.githubusercontent.com)"
  type        = bool
  default     = true
}

variable "deploy_admin_access" {
  description = "true = attach AdministratorAccess to the deploy role (simplest). false (default) = scoped-but-generous policy listing the services the prod stack manages"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags merged into every bootstrap resource"
  type        = map(string)
  default     = {}
}

variable "state_bucket_kms_key_arn" {
  description = "KMS key for the state bucket's default encryption. Empty = SSE-S3 (AES256). Set when importing a bucket that already uses SSE-KMS."
  type        = string
  default     = ""
}

variable "state_lifecycle_rule_id" {
  description = "Lifecycle rule id (set to the existing id when importing a bucket)"
  type        = string
  default     = "expire-old-state-versions"
}

variable "state_noncurrent_days" {
  description = "Days before noncurrent state versions expire"
  type        = number
  default     = 30
}
