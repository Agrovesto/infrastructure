# =============================================================================
# EventBridge Scheduler — start/stop the EC2 host on a schedule
# =============================================================================

resource "aws_scheduler_schedule_group" "ec2" {
  name = "${local.name}-ec2"

  tags = local.tags
}

resource "aws_scheduler_schedule" "start" {
  name                         = "${local.name}-ec2-start"
  group_name                   = aws_scheduler_schedule_group.ec2.name
  schedule_expression          = var.ec2_start_cron
  schedule_expression_timezone = var.scheduler_timezone
  state                        = var.enable_ec2_scheduler ? "ENABLED" : "DISABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ InstanceIds = [aws_instance.app.id] })
  }
}

resource "aws_scheduler_schedule" "stop" {
  name                         = "${local.name}-ec2-stop"
  group_name                   = aws_scheduler_schedule_group.ec2.name
  schedule_expression          = var.ec2_stop_cron
  schedule_expression_timezone = var.scheduler_timezone
  state                        = var.enable_ec2_scheduler ? "ENABLED" : "DISABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ InstanceIds = [aws_instance.app.id] })
  }
}
