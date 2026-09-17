# =============================================================================
# Data sources
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- IAM: EC2 host role ------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ec2" {
  #checkov:skip=CKV_AWS_111: ssmmessages/ec2messages offer no resource-level permissions, so Resource "*" is required by AWS
  #checkov:skip=CKV_AWS_356: ssmmessages/ec2messages offer no resource-level permissions, so Resource "*" is required by AWS
  statement {
    sid       = "MssqlBackupS3"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:DeleteObject"]
    resources = [aws_s3_bucket.backup.arn, "${aws_s3_bucket.backup.arn}/*"]
  }

  # SSM agent only. There is deliberately no logs:* here: the app logs are read
  # off the docker daemon on this host and stored in Loki on this host, so the
  # instance has no business talking to CloudWatch Logs (see dev/logging.tf).
  # The one S3 read below is the config pull at boot, not a log shipping path.
  statement {
    sid = "SsmAgent"
    actions = [
      "ssm:UpdateInstanceInformation",
      "ssmmessages:*",
      "ec2messages:*"
    ]
    resources = ["*"]
  }

  # The single read of the rendered host config at boot (dev/host_config.tf).
  # Read-only, and the bucket name is fixed by local.host_config_bucket, so this
  # is not a way to enumerate the account's buckets.
  statement {
    sid     = "HostConfigS3"
    actions = ["s3:GetObject", "s3:ListBucket"]

    resources = [
      aws_s3_bucket.host_config.arn,
      "${aws_s3_bucket.host_config.arn}/*",
    ]
  }

  # Docker login on the EC2 host (user_data) — GetAuthorizationToken has no
  # resource-level scoping by AWS design (covered by the document-level skips).
  statement {
    sid       = "EcrRegistryAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Pull-only access to this stack's own API repos (compose's agrovesto-dev-* images).
  statement {
    sid       = "EcrPullApis"
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
    resources = [for repo in values(aws_ecr_repository.apis) : repo.arn]
  }
}

# --- IAM: EventBridge scheduler role ----------------------------------------

data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "scheduler" {
  statement {
    actions   = ["ec2:StartInstances", "ec2:StopInstances"]
    resources = [aws_instance.app.arn]
  }
}
