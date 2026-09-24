# =============================================================================
# Baseline CloudWatch alarms for the dev EC2 host -> SNS alerts topic (sns.tf)
#
# Only EC2 metrics AWS publishes itself (the host runs no CloudWatch agent).
# Disk and container alerts come from the host's Prometheus/Alertmanager.
# The scheduler stops the host out of hours, so missing data is not breaching.
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "ec2_status_check" {
  alarm_name          = "${local.name}-host-status-check-failed"
  alarm_description   = "Dev host ${aws_instance.app.id} failed its EC2 status checks"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  dimensions          = { InstanceId = aws_instance.app.id }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  alarm_name          = "${local.name}-host-cpu-high"
  alarm_description   = "Dev host CPU above ${var.alarm_cpu_percent}% for 15 minutes"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { InstanceId = aws_instance.app.id }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.alarm_cpu_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  tags                = local.tags
}

# --- Alertmanager on the host publishes to the same topic ---------------------
resource "aws_iam_role_policy" "ec2_alerts_sns" {
  name = "${local.name}-ec2-alerts-sns"
  role = aws_iam_role.ec2.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AlertmanagerPublish"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Sid      = "EncryptForSns"
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey*", "kms:Decrypt"]
        Resource = aws_kms_key.sns.arn
      }
    ]
  })
}
