# =============================================================================
# SQL Server Express database-size guard
#
# Express caps every database at 10 GB (10240 MB). At the cap, writes simply
# start failing — RDS emits no event for it, and Express has no SQL Server
# Agent to run a scheduled alert. So the check has to come from outside:
#
#   EventBridge (rate) -> Fargate task running sqlcmd -> CloudWatch Logs
#   -> metric filter counting "DB_SIZE_ALERT" -> CloudWatch alarm -> SNS
#
# No new image and no build step: mcr.microsoft.com/mssql-tools ships sqlcmd
# and is already used by the db-init task. Two runs a day at 256 CPU costs a
# few cents, and the alarm plus one custom metric is ~$0.40/mo.
# =============================================================================

# CloudWatch default encryption is enough here too - mirrors checkov CKV_AWS_158 skip.
#trivy:ignore:AVD-AWS-0017
resource "aws_cloudwatch_log_group" "db_size_check" {
  count = var.db_size_alarm_enabled ? 1 : 0

  name              = "/ecs/${local.name}/db-size-check"
  retention_in_days = var.log_retention_days

  tags = local.tags
}

resource "aws_ecs_task_definition" "db_size_check" {
  count = var.db_size_alarm_enabled ? 1 : 0

  family                   = local.db_size_check_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  # Deliberately NOT Graviton, same reason as the db-init task:
  # mcr.microsoft.com/mssql-tools ships amd64 only.
  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "db-size-check"
      image     = var.db_size_check_image
      essential = true

      # -b makes sqlcmd exit non-zero on error, so a failed run shows up as a
      # failed ECS task instead of silence. -h -1 -W strips headers and padding
      # so each line is exactly "DB_SIZE_OK <db> <size>MB" or "DB_SIZE_ALERT …".
      command = [
        "sh", "-c",
        "set -e; sqlcmd -b -S $DB_HOST,$DB_PORT -U $DB_USER -P \"$DB_PASSWORD\" -l 30 -h -1 -W -Q \"${local.db_size_check_sql}\""
      ]

      environment = [
        { name = "DB_HOST", value = split(":", aws_db_instance.mssql.endpoint)[0] },
        { name = "DB_PORT", value = tostring(var.mssql_port) }
      ]

      secrets = [
        { name = "DB_USER", valueFrom = "${local.mssql_master_secret_arn}:username::" },
        { name = "DB_PASSWORD", valueFrom = "${local.mssql_master_secret_arn}:password::" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.db_size_check[0].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = local.tags
}

# The role EventBridge assumes to start the task.
resource "aws_iam_role" "events" {
  count = var.db_size_alarm_enabled ? 1 : 0

  name               = "${local.name}-events-role"
  assume_role_policy = can(jsondecode(try(data.aws_iam_policy_document.events_assume[0].json, ""))) ? data.aws_iam_policy_document.events_assume[0].json : "{\"Version\":\"2012-10-17\",\"Statement\":[]}"

  tags = local.tags
}

resource "aws_iam_role_policy" "events_run_task" {
  count = var.db_size_alarm_enabled ? 1 : 0

  name   = "${local.name}-events-run-task"
  role   = aws_iam_role.events[0].id
  policy = can(jsondecode(try(data.aws_iam_policy_document.events_run_task[0].json, ""))) ? data.aws_iam_policy_document.events_run_task[0].json : "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
}

resource "aws_cloudwatch_event_rule" "db_size_check" {
  count = var.db_size_alarm_enabled ? 1 : 0

  name                = "${local.name}-db-size-check"
  description         = "Runs the SQL Server Express database-size check (10 GB per-database cap)."
  schedule_expression = var.db_size_check_schedule

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "db_size_check" {
  count = var.db_size_alarm_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.db_size_check[0].name
  target_id = "db-size-check"
  arn       = aws_ecs_cluster.main.arn
  role_arn  = aws_iam_role.events[0].arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.db_size_check[0].arn
    task_count          = 1
    launch_type         = "FARGATE"

    network_configuration {
      subnets          = [aws_subnet.private[0].id]
      security_groups  = [aws_security_group.ecs.id]
      assign_public_ip = false
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "db_size_alert" {
  count = var.db_size_alarm_enabled ? 1 : 0

  name           = "${local.name}-db-size-alert"
  log_group_name = aws_cloudwatch_log_group.db_size_check[0].name
  pattern        = "\"DB_SIZE_ALERT\""

  metric_transformation {
    name          = "DBSizeAlertCount"
    namespace     = "${local.name}/rds"
    value         = "1"
    default_value = "0"
  }
}

# Period is a day, not an hour: the check only runs every 12 hours, so an
# hourly alarm would fire, clear an hour later and fire again twelve hours
# later. A 24h window holds the alarm steady while the condition persists.
resource "aws_cloudwatch_metric_alarm" "db_size" {
  count = var.db_size_alarm_enabled ? 1 : 0

  alarm_name  = "${local.name}-db-nearing-express-cap"
  namespace   = "${local.name}/rds"
  metric_name = "DBSizeAlertCount"

  statistic           = "Maximum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_description = join(" ", [
    "A database passed ${var.db_size_alarm_threshold_mb} MB.",
    "SQL Server Express caps each database at 10240 MB and writes fail at the cap.",
    "Remedy: snapshot -> restore as sqlserver-web or sqlserver-se on db.m7i.large -> rename to keep the endpoint.",
  ])
  alarm_actions = var.db_size_alarm_email != "" ? [aws_sns_topic.db_size_alarm[0].arn] : []
  ok_actions    = var.db_size_alarm_email != "" ? [aws_sns_topic.db_size_alarm[0].arn] : []

  tags = local.tags
}

resource "aws_sns_topic" "db_size_alarm" {
  count = var.db_size_alarm_enabled && var.db_size_alarm_email != "" ? 1 : 0

  name              = "${local.name}-db-size-alarm"
  kms_master_key_id = aws_kms_key.sns.arn

  tags = local.tags
}

resource "aws_sns_topic_subscription" "db_size_alarm" {
  count = var.db_size_alarm_enabled && var.db_size_alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.db_size_alarm[0].arn
  protocol  = "email"
  endpoint  = var.db_size_alarm_email
}
