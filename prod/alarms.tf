# =============================================================================
# Baseline CloudWatch alarms -> SNS alerts topic (sns.tf)
# RDS, ALB and each ECS service. ok_actions also notify on recovery.
# =============================================================================

locals {
  alarm_actions = [aws_sns_topic.alerts.arn]
}

# --- RDS ----------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name}-rds-cpu-high"
  alarm_description   = "RDS ${aws_db_instance.mssql.identifier} CPU above ${var.alarm_rds_cpu_percent}% for 15 minutes"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.mssql.identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.alarm_rds_cpu_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${local.name}-rds-free-storage-low"
  alarm_description   = "RDS ${aws_db_instance.mssql.identifier} free storage below ${var.alarm_rds_free_storage_gb} GB"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.mssql.identifier }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.alarm_rds_free_storage_gb * 1024 * 1024 * 1024
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_memory" {
  alarm_name          = "${local.name}-rds-freeable-memory-low"
  alarm_description   = "RDS ${aws_db_instance.mssql.identifier} freeable memory below ${var.alarm_rds_free_memory_mb} MB for 15 minutes"
  namespace           = "AWS/RDS"
  metric_name         = "FreeableMemory"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.mssql.identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.alarm_rds_free_memory_mb * 1024 * 1024
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.tags
}

# --- ALB ----------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name}-alb-5xx"
  alarm_description   = "ALB itself returned ${var.alarm_5xx_count}+ 5xx responses in 5 minutes"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  dimensions          = { LoadBalancer = aws_lb.main.arn_suffix }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.alarm_5xx_count
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  for_each = var.services

  alarm_name          = "${local.name}-${each.key}-5xx"
  alarm_description   = "${each.key} returned ${var.alarm_5xx_count}+ 5xx responses in 5 minutes"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = aws_lb.main.arn_suffix, TargetGroup = aws_lb_target_group.services[each.key].arn_suffix }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.alarm_5xx_count
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  for_each = var.services

  alarm_name          = "${local.name}-${each.key}-unhealthy"
  alarm_description   = "${each.key} has unhealthy targets for 5 minutes"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = { LoadBalancer = aws_lb.main.arn_suffix, TargetGroup = aws_lb_target_group.services[each.key].arn_suffix }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.tags
}

# --- ECS ----------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  for_each = var.services

  alarm_name          = "${local.name}-${each.key}-cpu-high"
  alarm_description   = "${each.key} CPU above ${var.alarm_ecs_percent}% for 15 minutes"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = { ClusterName = aws_ecs_cluster.main.name, ServiceName = aws_ecs_service.services[each.key].name }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.alarm_ecs_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  for_each = var.services

  alarm_name          = "${local.name}-${each.key}-memory-high"
  alarm_description   = "${each.key} memory above ${var.alarm_ecs_percent}% for 15 minutes"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  dimensions          = { ClusterName = aws_ecs_cluster.main.name, ServiceName = aws_ecs_service.services[each.key].name }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.alarm_ecs_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.tags
}
