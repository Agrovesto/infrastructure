# =============================================================================
# Data sources — bootstrap
# =============================================================================

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# GitHub Actions OIDC thumbprints, discovered live from the endpoint.
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  name = "${var.project}-${var.environment}"

  state_bucket_name = var.state_bucket_name != "" ? var.state_bucket_name : "nomaos-tfstate-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  oidc_url = "https://token.actions.githubusercontent.com"

  # The ARN the deploy role trusts, whether we create the provider here or
  # it already exists in the account.
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"

  tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      Stack       = "bootstrap"
    },
    var.tags
  )
}

# --- Deploy role trust policy ---------------------------------------------------

data "aws_iam_policy_document" "deploy_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_sub_patterns
    }
  }
}

# --- Deploy role permissions (scoped-but-generous) -------------------------------
#
# The role is assumed by GitHub Actions to run `terraform plan/apply` on the
# prod stack, so it must be able to manage every AWS service the stack
# creates. Tighten later with a permissions boundary once the stack settles.

data "aws_iam_policy_document" "deploy_scoped" {
  #checkov:skip=CKV_AWS_109: Terraform-managed deploy role — it must be able to create IAM roles/policies for the stack (EFS/ECS/RDS/ALB depend on it). Scope down later with a permissions boundary.
  #checkov:skip=CKV_AWS_111: write access across the managed services is the point of the deploy role.
  #checkov:skip=CKV_AWS_286: see above
  #checkov:skip=CKV_AWS_355: see above
  #checkov:skip=CKV_AWS_356: service-level * actions on * resources are required because Terraform creates arbitrarily-named resources in the account.
  #checkov:skip=CKV_AWS_107: broad permissions are the definition of a Terraform deploy role; cap with a permissions boundary later.
  #checkov:skip=CKV_AWS_108: broad permissions are the definition of a Terraform deploy role; cap with a permissions boundary later.
  #checkov:skip=CKV_AWS_110: broad permissions are the definition of a Terraform deploy role; cap with a permissions boundary later.
  statement {
    sid = "ManagedServices"
    actions = [
      "ec2:*",                  # VPC, subnets, route tables, SGs, EIPs, NAT, flow logs
      "ecs:*",                  # cluster, task definitions, services
      "ecr:*",                  # repositories, lifecycle policies
      "elasticloadbalancing:*", # ALB, target groups, listeners, rules
      "rds:*",                  # SQL Server instance, subnet group, monitoring
      "acm:*",                  # wildcard certificate + validation
      "s3:*",                   # ALB access-log bucket (+ tfstate reads below)
      "secretsmanager:*",       # master-secret bootstrap
      "logs:*",                 # service/flow/vault log groups
      "kms:*",                  # Vault unseal/EFS CMK
      "elasticfilesystem:*",    # Vault raft storage
      "cloudwatch:*",
      "sns:*",
      "rekognition:*",
      "sqs:*",
      "application-autoscaling:*",
      "events:*",
      "servicediscovery:*",
      "cur:*",
      "ses:*",
      "ssm:*",
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }

  statement {
    sid = "Route53ZoneManagement"
    actions = [
      "route53:*",
      "route53domains:Get*",
      "route53domains:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid = "IamForTerraform"
    actions = [
      "iam:*",
      "sts:DecodeAuthorizationMessage"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "TerraformStateBucket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.state_bucket_name}"]
  }

  statement {
    sid       = "TerraformStateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${local.state_bucket_name}/*"]
  }
}

# --- tfstate bucket policy: enforce TLS ------------------------------------------

data "aws_iam_policy_document" "state_bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${local.state_bucket_name}",
      "arn:aws:s3:::${local.state_bucket_name}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}
