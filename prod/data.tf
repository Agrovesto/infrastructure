# =============================================================================
# Data sources
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Regional ELB account, used for the ALB access-log bucket policy.
data "aws_elb_service_account" "main" {}

# --- IAM: ECS task execution (pulls from ECR, writes logs, reads secrets) ----

data "aws_iam_policy_document" "ecs_execution_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

#checkov:skip=CKV_AWS_356: Secrets Access is scoped to the instance's own master secret; the wildcard on the KMS key covers the AWS-managed aws/secretsmanager key
data "aws_iam_policy_document" "ecs_execution_secrets" {
  statement {
    sid       = "ReadMssqlMasterSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.mssql_master.arn]
  }
}

# --- IAM: RDS enhanced monitoring ---------------------------------------------

data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

# --- IAM: VPC flow logs --------------------------------------------------------

data "aws_iam_policy_document" "flow_logs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

#checkov:skip=CKV_AWS_355: flow-log delivery is scoped to this stack's own log group
data "aws_iam_policy_document" "flow_logs" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = [
      aws_cloudwatch_log_group.flow_logs.arn,
      "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    ]
  }
}

# --- S3: ALB access logs bucket policy ----------------------------------------

#checkov:skip=CKV_AWS_356: s3:PutObject is scoped to the AWSLogs/<account> prefix of the log bucket; the region-wide SourceArn just anticipates future ALBs
data "aws_iam_policy_document" "alb_logs" {
  # Modern pattern: the ELB log delivery service principal.
  statement {
    sid     = "AllowELBLogDelivery"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elb.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/app/*"]
    }
  }

  # Legacy pattern: the regional ELB service account (still required in
  # several regions, harmless elsewhere).
  statement {
    sid     = "AllowELBServiceAccount"
    actions = ["s3:PutObject"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_elb_service_account.main.id}:root"]
    }

    resources = ["${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
  }
}
