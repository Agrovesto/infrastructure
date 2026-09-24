# =============================================================================
# SNS: infra alerts + application notification topics
#
# * alerts: CloudWatch alarms (alarms.tf) publish here; subscribers get email.
# * app topics (var.app_sns_topics): the APIs on the EC2 host publish to them
#   through the instance role.
#
# Encryption: a customer-managed KMS key, because CloudWatch alarms cannot
# publish to topics encrypted with the AWS-managed aws/sns key.
# Email subscriptions stay "PendingConfirmation" until each recipient clicks
# the confirmation link AWS emails them.
# =============================================================================

resource "aws_kms_key" "sns" {
  description             = "${local.name} SNS topics"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAdmin"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AwsServicesPublish"
        Effect    = "Allow"
        Principal = { Service = ["cloudwatch.amazonaws.com", "events.amazonaws.com"] }
        Action    = ["kms:Decrypt", "kms:GenerateDataKey*"]
        Resource  = "*"
      }
    ]
  })

  tags = local.tags
}

resource "aws_kms_alias" "sns" {
  name          = "alias/${local.name}-sns"
  target_key_id = aws_kms_key.sns.key_id
}

resource "aws_sns_topic" "alerts" {
  name              = "${local.name}-alerts"
  kms_master_key_id = aws_kms_key.sns.arn

  tags = local.tags
}

resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "CloudWatchAndEventsPublish"
        Effect    = "Allow"
        Principal = { Service = ["cloudwatch.amazonaws.com", "events.amazonaws.com"] }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.alerts.arn
        Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "alerts_email" {
  for_each = toset(var.alert_emails)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic" "app" {
  for_each = toset(var.app_sns_topics)

  name              = "${local.name}-${each.value}"
  kms_master_key_id = aws_kms_key.sns.arn

  tags = local.tags
}

resource "aws_sns_topic_subscription" "app_email" {
  for_each = { for p in setproduct(var.app_sns_topics, var.app_topic_emails) : "${p[0]}/${p[1]}" => { topic = p[0], email = p[1] } }

  topic_arn = aws_sns_topic.app[each.value.topic].arn
  protocol  = "email"
  endpoint  = each.value.email
}

# The APIs on the EC2 host publish to the app topics.
resource "aws_iam_role_policy" "ec2_sns" {
  count = length(var.app_sns_topics) > 0 ? 1 : 0

  name = "${local.name}-ec2-sns"
  role = aws_iam_role.ec2.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = [for t in aws_sns_topic.app : t.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey*", "kms:Decrypt"]
        Resource = aws_kms_key.sns.arn
      }
    ]
  })
}
