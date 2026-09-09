resource "aws_scheduler_schedule_group" "this" {
  name = "${var.name}-ec2"
  tags = var.tags
}

resource "aws_scheduler_schedule" "start" {
  name                         = "${var.name}-ec2-start"
  group_name                   = aws_scheduler_schedule_group.this.name
  schedule_expression          = var.start_cron
  schedule_expression_timezone = var.timezone
  state                        = var.enabled ? "ENABLED" : "DISABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = var.scheduler_role_arn
    input    = jsonencode({ InstanceIds = [var.instance_id] })
  }

  tags = var.tags
}

resource "aws_scheduler_schedule" "stop" {
  name                         = "${var.name}-ec2-stop"
  group_name                   = aws_scheduler_schedule_group.this.name
  schedule_expression          = var.stop_cron
  schedule_expression_timezone = var.timezone
  state                        = var.enabled ? "ENABLED" : "DISABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = var.scheduler_role_arn
    input    = jsonencode({ InstanceIds = [var.instance_id] })
  }

  tags = var.tags
}
