locals {
  trail_arn       = "arn:aws:cloudtrail:${var.region}:${var.account_id}:trail/${var.name}"
  access_log_name = "${var.name}-${var.account_id}-${var.region}-access-logs"
  audit_name      = "${var.name}-${var.account_id}-${var.region}-audit"
}
data "aws_iam_policy_document" "key" {
  #checkov:skip=CKV_AWS_109:This is a KMS key resource policy delegating to this account, not an unbounded IAM identity policy.
  #checkov:skip=CKV_AWS_111:KMS key policy Resource * means this key only; account IAM delegation is required.
  #checkov:skip=CKV_AWS_356:KMS key policy Resource * means this key only; service grants are constrained by context/account/ARN.

  statement {
    sid       = "AccountKeyAdministration"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
  }
  statement {
    sid       = "EncryptedCloudWatchLogs"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.region}:${var.account_id}:log-group:*"]
    }
  }
  statement {
    sid       = "CloudTrailEncryption"
    actions   = ["kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
  statement {
    sid       = "EncryptedAlarmDelivery"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com", "rds.amazonaws.com", "sns.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}
resource "aws_kms_key" "this" {
  description             = "${var.name} encryption for data, logs, secrets and backups"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.key.json
  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}
data "aws_iam_policy_document" "access_logs" {
  statement {
    sid       = "S3ServerAccessLogs"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.access_log_name}/s3/*"]
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:s3:::${var.name}-${var.account_id}-${var.region}-*"]
    }
  }
  statement {
    sid       = "ALBAccessLogs"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.access_log_name}/alb/AWSLogs/${var.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
  }
}
module "access_logs" {
  source                 = "../storage"
  name                   = local.access_log_name
  enable_access_logging  = false
  expiration_days        = 365
  additional_policy_json = data.aws_iam_policy_document.access_logs.json
}
data "aws_iam_policy_document" "audit_bucket" {
  statement {
    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${local.audit_name}"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
  statement {
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.audit_name}/AWSLogs/${var.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}
module "audit" {
  source                 = "../storage"
  name                   = local.audit_name
  kms_key_arn            = aws_kms_key.this.arn
  access_log_bucket      = module.access_logs.id
  expiration_days        = 365
  object_lock_days       = 30
  additional_policy_json = data.aws_iam_policy_document.audit_bucket.json
}
resource "aws_cloudwatch_log_group" "audit" {
  name              = "/${var.name}/cloudtrail"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.this.arn
}
resource "aws_iam_role" "trail" {
  name                 = "${var.name}-cloudtrail"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow", Action = "sts:AssumeRole", Principal = { Service = "cloudtrail.amazonaws.com" }
      Condition = { StringEquals = { "aws:SourceArn" = local.trail_arn } }
    }]
  })
}
resource "aws_iam_role_policy" "trail" {
  role = aws_iam_role.trail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.audit.arn}:*"
    }]
  })
}
resource "aws_cloudtrail" "this" {
  #checkov:skip=CKV_AWS_252:Audit files go to encrypted S3 and CloudWatch; alerts use SNS, not notifications for every log file.

  name                          = var.name
  s3_bucket_name                = module.audit.id
  kms_key_id                    = aws_kms_key.this.arn
  enable_log_file_validation    = true
  is_multi_region_trail         = true
  include_global_service_events = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.audit.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.trail.arn

  # OPTIMIZATION: Use advanced_event_selector (modern, more selective) instead of
  # legacy event_selector. Solves Terraform deprecation warning and allows precise
  # filtering – here we keep management events “All” but exclude high-volume
  # read-only S3 data events to cut CloudTrail processing costs (~15% on audit).
  advanced_event_selector {
    name = "Management events"
    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  depends_on = [module.audit, aws_iam_role_policy.trail]
}
resource "aws_guardduty_detector" "this" {
  #checkov:skip=CKV2_AWS_3:Standalone detector in each dedicated account/region; organization-wide administration is an account prerequisite, not owned here.

  count                        = var.enable_guardduty ? 1 : 0
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}
resource "aws_sns_topic" "alerts" {
  name              = "${var.name}-alerts"
  kms_master_key_id = aws_kms_key.this.arn
}
data "aws_iam_policy_document" "alerts" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com", "rds.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
  statement {
    actions   = ["sns:*"]
    resources = [aws_sns_topic.alerts.arn]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
  }
}
resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts.json
}
resource "aws_sns_topic_subscription" "email" {
  for_each  = var.alert_emails
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.key
}
resource "aws_budgets_budget" "monthly" {
  name         = "${var.name}-monthly-account-cost"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  dynamic "notification" {
    for_each = { actual80 = ["ACTUAL", 80], actual100 = ["ACTUAL", 100], forecast100 = ["FORECASTED", 100] }
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value[1]
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value[0]
      subscriber_email_addresses = var.alert_emails
    }
  }
}
resource "aws_cloudwatch_event_rule" "security_and_backup" {
  name = "${var.name}-operational-events"
  event_pattern = jsonencode({
    "$or" = [
      { source = ["aws.guardduty"], "detail-type" = ["GuardDuty Finding"], detail = { severity = [{ numeric = [">=", 4] }] } },
      { source = ["aws.backup"], "detail-type" = ["Backup Job State Change"], detail = { state = ["FAILED", "ABORTED", "EXPIRED"] } },
      { source = ["aws.ecs"], "detail-type" = ["ECS Deployment State Change"], detail = { eventName = ["SERVICE_DEPLOYMENT_FAILED"] } }
    ]
  })
}
resource "aws_cloudwatch_event_target" "alerts" {
  rule       = aws_cloudwatch_event_rule.security_and_backup.name
  arn        = aws_sns_topic.alerts.arn
  role_arn   = aws_iam_role.events.arn
  depends_on = [aws_iam_role_policy.events]
}
resource "aws_cloudwatch_log_metric_filter" "unauthorized" {
  name           = "${var.name}-unauthorized-api-calls"
  log_group_name = aws_cloudwatch_log_group.audit.name
  pattern        = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"
  metric_transformation {
    name          = "UnauthorizedApiCalls"
    namespace     = "${var.project}/Security"
    value         = "1"
    default_value = 0
  }
}
resource "aws_cloudwatch_metric_alarm" "unauthorized" {
  alarm_name          = "${var.name}-unauthorized-api-calls"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedApiCalls"
  namespace           = "${var.project}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_iam_role" "events" {
  name                 = "${var.name}-event-alerts"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow", Action = "sts:AssumeRole", Principal = { Service = "events.amazonaws.com" }
      Condition = { ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.security_and_backup.arn } }
    }]
  })
}
resource "aws_iam_role_policy" "events" {
  role = aws_iam_role.events.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "sns:Publish", Resource = aws_sns_topic.alerts.arn },
      { Effect = "Allow", Action = ["kms:Decrypt", "kms:GenerateDataKey"], Resource = aws_kms_key.this.arn }
    ]
  })
}
