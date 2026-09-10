# =============================================================================
# Data sources
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "al2023" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
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
  #checkov:skip=CKV_AWS_111: ssmmessages/ec2messages and logs:CreateLogGroup offer no resource-level permissions, so Resource "*" is required by AWS
  #checkov:skip=CKV_AWS_356: ssmmessages/ec2messages and logs:CreateLogGroup offer no resource-level permissions, so Resource "*" is required by AWS
  statement {
    sid       = "MssqlBackupS3"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:DeleteObject"]
    resources = [aws_s3_bucket.backup.arn, "${aws_s3_bucket.backup.arn}/*"]
  }

  statement {
    sid = "SsmAndLogs"
    actions = [
      "ssm:UpdateInstanceInformation",
      "ssmmessages:*",
      "ec2messages:*",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
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
