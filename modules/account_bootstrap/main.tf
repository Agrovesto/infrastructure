locals {
  name              = "${var.project}-bootstrap-${var.environment}"
  workload_prefix   = "${var.project}-${var.environment}"
  state_bucket_name = "${var.project}-tfstate-${var.account_id}-${var.region}"
  log_bucket_name   = "${var.project}-tfstate-logs-${var.account_id}-${var.region}"
  state_key         = "${var.environment}/terraform.tfstate"
  bootstrap_key     = "${var.environment}/bootstrap.tfstate"
  github_subject    = var.github_oidc_subject == null ? "repo:${var.github_repository}:environment:${var.environment}:ref:refs/heads/${var.environment}:event_name:push:workflow_ref:${var.github_repository}/.github/workflows/infrastructure.yml@refs/heads/${var.environment}" : var.github_oidc_subject
}
resource "aws_kms_key" "state" {
  description             = "${local.name} Terraform state encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }, Action = "kms:*", Resource = "*" }]
  })
  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_kms_alias" "state" {
  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.state.key_id
}
module "state_logs" {
  source                = "../storage"
  name                  = local.log_bucket_name
  enable_access_logging = false
  expiration_days       = 365
  additional_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow", Principal = { Service = "logging.s3.amazonaws.com" }
      Action = "s3:PutObject", Resource = "arn:aws:s3:::${local.log_bucket_name}/s3/*"
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.account_id }
        ArnEquals    = { "aws:SourceArn" = "arn:aws:s3:::${local.state_bucket_name}" }
      }
    }]
  })
}
module "state" {
  source            = "../storage"
  name              = local.state_bucket_name
  kms_key_arn       = aws_kms_key.state.arn
  access_log_bucket = module.state_logs.id
  noncurrent_days   = 365
  # No Object Lock on the state bucket: Terraform must be able to delete .tflock.
}
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.existing_oidc_provider_arn == null ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # AWS validates GitHub against its trusted CA set; no stale hard-coded thumbprints.
}
# This boundary is created by a human bootstrap operator, never by the CI role.
# Workload roles can neither administer IAM nor read/modify Terraform state.
resource "aws_iam_policy" "workload_boundary" {
  name        = "${local.name}-workload-boundary"
  description = "Maximum runtime permissions; each workload still needs a narrowly scoped identity policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "RuntimeCapabilitiesOnly", Effect = "Allow", Resource = "*"
        Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams", "logs:PutRetentionPolicy",
          "cloudwatch:PutMetricData", "sns:Publish",
          "backup:DescribeBackupVault", "backup:DescribeRecoveryPoint", "backup:ListTags", "backup:TagResource",
          "ecr:GetAuthorizationToken", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability",
          "secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret", "secretsmanager:GetRandomPassword", "secretsmanager:PutSecretValue",
          "s3:Get*", "s3:List*", "s3:PutObject", "s3:AbortMultipartUpload",
          "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey", "kms:CreateGrant", "kms:ListGrants", "kms:RetireGrant",
          "ec2:Describe*", "ec2:CreateSnapshot", "ec2:CreateSnapshots", "ec2:CopySnapshot", "ec2:DeleteSnapshot", "ec2:CreateTags", "ec2:DeleteTags", "ec2:ModifySnapshotAttribute",
          "ssm:DescribeAssociation", "ssm:GetDeployablePatchSnapshotForInstance", "ssm:GetDocument", "ssm:DescribeDocument", "ssm:GetManifest", "ssm:GetParameter", "ssm:GetParameters",
          "ssm:ListAssociations", "ssm:ListInstanceAssociations", "ssm:PutInventory", "ssm:PutComplianceItems", "ssm:PutConfigurePackageResult",
          "ssm:UpdateAssociationStatus", "ssm:UpdateInstanceAssociationStatus", "ssm:UpdateInstanceInformation", "ssmmessages:*", "ec2messages:*"
        ]
      },
      { Sid = "NoTerraformState", Effect = "Deny", Action = "s3:*", Resource = [module.state.arn, "${module.state.arn}/*", module.state_logs.arn, "${module.state_logs.arn}/*"] },
      { Sid = "NoTerraformKey", Effect = "Deny", Action = "kms:*", Resource = aws_kms_key.state.arn }
    ]
  })
  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_iam_role" "deploy" {
  name                 = "${local.name}-deploy"
  max_session_duration = 7200
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow", Action = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = var.existing_oidc_provider_arn == null ? aws_iam_openid_connect_provider.github[0].arn : var.existing_oidc_provider_arn }
      Condition = { StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        "token.actions.githubusercontent.com:sub" = local.github_subject
      } }
    }]
  })
  lifecycle {
    prevent_destroy = true
  }
}
# This is an intentionally powerful *infrastructure provisioning* role in a
# dedicated account, not an application role. Review docs/security.md before use.
resource "aws_iam_role_policy" "provisioning" {
  name = "ProvisionInfrastructureServices"
  role = aws_iam_role.deploy.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "InfrastructureServices", Effect = "Allow", Resource = "*"
        Action = [
          "ec2:*", "elasticloadbalancing:*", "ecs:*", "ecr:*", "rds:*", "application-autoscaling:*", "autoscaling:Describe*",
          "s3:*", "kms:*", "logs:*", "cloudwatch:*", "sns:*", "budgets:*", "backup:*", "events:*", "ssm:*", "secretsmanager:*",
          "acm:*", "route53:*", "amplify:*", "wafv2:*", "cloudtrail:*", "guardduty:*"
        ]
      },
      {
        Sid      = "ProtectBackendConfiguration", Effect = "Deny"
        Action   = ["s3:DeleteBucket", "s3:DeleteBucketPolicy", "s3:PutBucket*", "s3:PutEncryptionConfiguration", "s3:PutLifecycleConfiguration", "s3:PutReplicationConfiguration", "s3:PutAccelerateConfiguration", "s3:DeleteObjectVersion"]
        Resource = [module.state.arn, "${module.state.arn}/*", module.state_logs.arn, "${module.state_logs.arn}/*"]
      },
      { Sid = "ProtectBootstrapState", Effect = "Deny", Action = "s3:*", Resource = "${module.state.arn}/${local.bootstrap_key}*" },
      { Sid = "DoNotDeleteEnvironmentState", Effect = "Deny", Action = "s3:DeleteObject", Resource = "${module.state.arn}/${local.state_key}" },
      { Sid = "ProtectBackendKey", Effect = "Deny", NotAction = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey*", "kms:DescribeKey"], Resource = [aws_kms_key.state.arn, aws_kms_alias.state.arn] }
    ]
  })
}
resource "aws_iam_role_policy" "iam" {
  name = "BoundedWorkloadIAM"
  role = aws_iam_role.deploy.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "IAMReadOnly", Effect = "Allow"
        Resource = ["arn:aws:iam::${var.account_id}:role/${local.workload_prefix}-*", "arn:aws:iam::${var.account_id}:role/aws-service-role/*", "arn:aws:iam::${var.account_id}:instance-profile/${local.workload_prefix}-*", aws_iam_policy.workload_boundary.arn, "arn:aws:iam::aws:policy/*"]
        Action   = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:GetInstanceProfile", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListInstanceProfilesForRole", "iam:ListRoleTags", "iam:ListInstanceProfileTags"]
      },
      {
        Sid       = "CreateOnlyBoundedRoles", Effect = "Allow", Action = "iam:CreateRole"
        Resource  = "arn:aws:iam::${var.account_id}:role/${local.workload_prefix}-*"
        Condition = { StringEquals = { "iam:PermissionsBoundary" = aws_iam_policy.workload_boundary.arn } }
      },
      {
        Sid      = "ManageOnlyWorkloadRoles", Effect = "Allow"
        Action   = ["iam:DeleteRole", "iam:UpdateRole", "iam:UpdateRoleDescription", "iam:UpdateAssumeRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:TagRole", "iam:UntagRole", "iam:DetachRolePolicy"]
        Resource = "arn:aws:iam::${var.account_id}:role/${local.workload_prefix}-*"
      },
      {
        Sid      = "ApprovedAWSRuntimePoliciesOnly", Effect = "Allow", Action = "iam:AttachRolePolicy"
        Resource = "arn:aws:iam::${var.account_id}:role/${local.workload_prefix}-*"
        Condition = { ArnEquals = { "iam:PolicyARN" = [
          "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
          "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup",
          "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
        ] } }
      },
      {
        Sid      = "ManageWorkloadInstanceProfiles", Effect = "Allow"
        Action   = ["iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile", "iam:TagInstanceProfile", "iam:UntagInstanceProfile"]
        Resource = "arn:aws:iam::${var.account_id}:instance-profile/${local.workload_prefix}-*"
      },
      {
        Sid       = "PassOnlyWorkloadRolesToServices", Effect = "Allow", Action = "iam:PassRole"
        Resource  = "arn:aws:iam::${var.account_id}:role/${local.workload_prefix}-*"
        Condition = { StringEquals = { "iam:PassedToService" = ["ec2.amazonaws.com", "ecs-tasks.amazonaws.com", "rds.amazonaws.com", "monitoring.rds.amazonaws.com", "backup.amazonaws.com", "vpc-flow-logs.amazonaws.com", "cloudtrail.amazonaws.com", "events.amazonaws.com"] } }
      },
      {
        Sid       = "RequiredServiceLinkedRoles", Effect = "Allow", Action = "iam:CreateServiceLinkedRole"
        Resource  = "arn:aws:iam::${var.account_id}:role/aws-service-role/*"
        Condition = { StringEquals = { "iam:AWSServiceName" = ["ecs.amazonaws.com", "ecs.application-autoscaling.amazonaws.com", "elasticloadbalancing.amazonaws.com", "rds.amazonaws.com", "backup.amazonaws.com", "guardduty.amazonaws.com"] } }
      }
    ]
  })
}
resource "aws_route53_zone" "bootstrap" {
  #checkov:skip=CKV2_AWS_38:DNSSEC requires registrar DS coordination; see docs/dns.md before enabling it.
  #checkov:skip=CKV2_AWS_39:Public DNS query logging is a separate us-east-1 extension, documented in docs/dns.md.
  count         = var.bootstrap_zone_name == null ? 0 : 1
  name          = var.bootstrap_zone_name
  comment       = "Account bootstrap owns this zone; environment stack owns its application records"
  force_destroy = false
  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_iam_role_policy" "protect_zone" {
  count = var.bootstrap_zone_name == null ? 0 : 1
  name  = "DoNotDeleteBootstrapZone"
  role  = aws_iam_role.deploy.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Deny", Action = "route53:DeleteHostedZone", Resource = aws_route53_zone.bootstrap[0].arn }]
  })
}
