# =============================================================================
# BOOTSTRAP — import the state bucket + deploy role that already exist.
#
# bootstrap/ has no backend block (local state) and its defaults target PROD.
# Run it once per account, each with its own local state file (RUNBOOK §2):
#
#   imports/stage.sh bootstrap && cd bootstrap && terraform init
#   AWS_PROFILE=agrovesto-prod terraform plan -state=prod.tfstate \
#     -var account_id=221434544570            # role agrovesto-prod-github-deploy
#   AWS_PROFILE=agrovesto-dev  terraform plan -state=dev.tfstate \
#     -var account_id=353833416626 -var environment=dev \
#     -var deploy_role_name=<nomaos-dev-github-terraform | nomaos-bootstrap-dev-deploy> \
#     -var state_bucket_kms_key_arn=arn:aws:kms:eu-west-1:353833416626:key/31f57b1f-cbde-4aa6-8c6e-18e129c80fb6
#   (the dev bucket was created by a "nomaos-bootstrap-dev" setup whose KMS key
#   exists. Keep the KMS arg only if `aws s3api get-bucket-encryption` shows aws:kms)
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

# Scoped policy (deploy_admin_access = false, the default). If the role has
# AdministratorAccess instead, pass -var deploy_admin_access=true and replace
# these two blocks with:
#   to = aws_iam_role_policy_attachment.deploy_admin[0]
#   id = "<role>/arn:aws:iam::aws:policy/AdministratorAccess"
import {
  to = aws_iam_policy.deploy_scoped[0]
  id = local.import_policy_arn
}

import {
  to = aws_iam_role_policy_attachment.deploy_scoped[0]
  id = "${var.deploy_role_name}/${local.import_policy_arn}"
}

import {
  to = aws_iam_openid_connect_provider.github[0]
  id = "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
}
