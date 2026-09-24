# =============================================================================
# One-shot import blocks: adopt the existing AWS resources into this stack's
# state (see docs/import-runbook.md). After the first clean apply they are
# no-ops; delete this file once `terraform plan` shows "No changes".
# =============================================================================

variable "account_id" {
  description = "Account being bootstrapped (import ids are account-scoped)"
  type        = string
}

locals {
  import_state_bucket = "nomaos-tfstate-${var.account_id}-eu-west-1"
  import_policy_arn   = "arn:aws:iam::${var.account_id}:policy/${var.deploy_role_name}-policy"
}

import {
  to = aws_s3_bucket.state
  id = local.import_state_bucket
}

import {
  to = aws_s3_bucket_public_access_block.state
  id = local.import_state_bucket
}

import {
  to = aws_s3_bucket_versioning.state
  id = local.import_state_bucket
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.state
  id = local.import_state_bucket
}

# discovery-{dev,prod}.txt: "STATE lifecycle: yes", "STATE policy: yes" in both accounts.
import {
  to = aws_s3_bucket_lifecycle_configuration.state
  id = local.import_state_bucket
}

import {
  to = aws_s3_bucket_policy.state
  id = local.import_state_bucket
}

import {
  to = aws_iam_role.deploy
  id = var.deploy_role_name
}

variable "import_deploy_policy" {
  description = "Import the existing <role>-policy + its attachment (true when this module created the role, false when the policy doesn't exist yet: apply creates it)"
  type        = bool
  default     = true
}

# Scoped policy (deploy_admin_access = false). for_each on import needs Terraform >= 1.7.
import {
  for_each = var.import_deploy_policy && !var.deploy_admin_access ? toset(["this"]) : toset([])
  to       = aws_iam_policy.deploy_scoped[0]
  id       = local.import_policy_arn
}

import {
  for_each = var.import_deploy_policy && !var.deploy_admin_access ? toset(["this"]) : toset([])
  to       = aws_iam_role_policy_attachment.deploy_scoped[0]
  id       = "${var.deploy_role_name}/${local.import_policy_arn}"
}

import {
  for_each = var.deploy_admin_access ? toset(["this"]) : toset([])
  to       = aws_iam_role_policy_attachment.deploy_admin[0]
  id       = "${var.deploy_role_name}/arn:aws:iam::aws:policy/AdministratorAccess"
}

import {
  to = aws_iam_openid_connect_provider.github[0]
  id = "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
}
