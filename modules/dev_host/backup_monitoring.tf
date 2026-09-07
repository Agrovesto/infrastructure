resource "aws_backup_vault" "this" {
  name          = "${var.name}-database"
  kms_key_arn   = var.kms_key_arn
  force_destroy = false
  lifecycle {
    prevent_destroy = true
  }
}
# Governance mode (no changeable_for_days): reversible by a privileged operator.
resource "aws_backup_vault_lock_configuration" "this" {
  backup_vault_name  = aws_backup_vault.this.name
  min_retention_days = 7
  max_retention_days = 120
}
resource "aws_iam_role" "backup" {
  name                 = "${var.name}-ebs-backup"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "backup.amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}
resource "aws_iam_role_policy" "backup_key" {
  role = aws_iam_role.backup.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey"], Resource = var.kms_key_arn },
      { Effect = "Allow", Action = ["kms:CreateGrant"], Resource = var.kms_key_arn, Condition = { Bool = { "kms:GrantIsForAWSResource" = "true" } } }
    ]
  })
}
resource "aws_backup_plan" "this" {
  name = "${var.name}-database-disk-daily"
  rule {
    rule_name         = "DailyEBS"
    target_vault_name = aws_backup_vault.this.name
    schedule          = "cron(0 4 * * ? *)"
    start_window      = 60
    completion_window = 180
    lifecycle {
      delete_after = 35
    }
  }
}
resource "aws_backup_selection" "this" {
  name         = "${var.name}-sql-data-only"
  plan_id      = aws_backup_plan.this.id
  iam_role_arn = aws_iam_role.backup.arn
  resources    = [aws_ebs_volume.database.arn]
  depends_on   = [aws_iam_role_policy_attachment.backup, aws_iam_role_policy.backup_key]
}
resource "aws_cloudwatch_metric_alarm" "backup" {
  alarm_name          = "${var.name}-sql-backup-missed-or-failed"
  alarm_description   = "A native backup failed or no successful heartbeat arrived in a UTC day. Inspect agrovesto-backup.service and S3 manifest.json."
  namespace           = "${var.project}/Backups"
  metric_name         = "DatabaseBackupSuccess"
  dimensions          = { Environment = "dev" }
  statistic           = "Minimum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [var.alerts_topic_arn]
  ok_actions          = [var.alerts_topic_arn]
}
resource "aws_cloudwatch_metric_alarm" "status" {
  alarm_name          = "${var.name}-instance-status"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  dimensions          = { InstanceId = aws_instance.this.id }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [var.alerts_topic_arn]
  ok_actions          = [var.alerts_topic_arn]
}
resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "${var.name}-cpu"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { InstanceId = aws_instance.this.id }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = [var.alerts_topic_arn]
}
resource "aws_cloudwatch_metric_alarm" "memory" {
  alarm_name          = "${var.name}-memory"
  namespace           = "${var.project}/System"
  metric_name         = "mem_used_percent"
  dimensions          = { InstanceId = aws_instance.this.id }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [var.alerts_topic_arn]
}
resource "aws_cloudwatch_metric_alarm" "disk" {
  for_each            = { root = "/", database = "/srv/mssql" }
  alarm_name          = "${var.name}-disk-${each.key}"
  namespace           = "${var.project}/System"
  metric_name         = "disk_used_percent"
  dimensions          = { InstanceId = aws_instance.this.id, path = each.value }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [var.alerts_topic_arn]
  ok_actions          = [var.alerts_topic_arn]
}
