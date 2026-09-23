# Prod SQL Server (RDS) metrics without CloudWatch, Performance Insights or the
# RDS enhanced-monitoring agent: a scheduled Fargate task runs DMV queries over
# TDS and pushes the results to Pushgateway, where Prometheus scrapes them.

# Adopted instance (imports/RUNBOOK.md): credentials live in the RDS-managed
# secret, read by ARN at runtime - nothing sensitive is copied into this state.
data "aws_db_instance" "mssql" {
  count = var.mssql_instance_identifier != "" ? 1 : 0

  db_instance_identifier = var.mssql_instance_identifier
}

locals {
  mssql_enabled = var.enable_rds_monitoring && (var.mssql_secret_name != "" || var.mssql_instance_identifier != "")

  # Secret id handed to the task (name or ARN both work with GetSecretValue).
  mssql_secret_id = var.mssql_instance_identifier != "" ? try(data.aws_db_instance.mssql[0].master_user_secret[0].secret_arn, "") : var.mssql_secret_name
  mssql_host      = var.mssql_instance_identifier != "" ? try(data.aws_db_instance.mssql[0].address, "") : ""
  mssql_port      = var.mssql_instance_identifier != "" ? try(tostring(data.aws_db_instance.mssql[0].port), "1433") : ""

  mssql_log_config = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.monitoring.name
      awslogs-region        = var.aws_region
      awslogs-stream-prefix = "mssql"
    }
  }
}

resource "aws_ecs_task_definition" "mssql_metrics" {
  count = local.mssql_enabled ? 1 : 0

  family                   = "${local.name}-mssql-metrics"
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  volume {
    name = "data"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.monitoring.id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.monitoring["rds"].id
      }
    }
  }

  container_definitions = jsonencode([
    local.init_container,
    {
      name      = "mssql-metrics"
      image     = local.images.mssql
      essential = true

      command = ["sh", "-c", "pip install --quiet --no-cache-dir pytds boto3 && python /rds/config/mssql_metrics.py"]

      environment = [
        { name = "DB_SECRET_NAME", value = local.mssql_secret_id },
        { name = "DB_HOST", value = local.mssql_host },
        { name = "DB_PORT", value = local.mssql_port },
        { name = "DB_NAME", value = var.mssql_database },
        { name = "AWS_REGION", value = var.aws_region },
        { name = "PUSHGATEWAY_URL", value = local.endpoints.pushgateway },
      ]

      mountPoints      = [{ sourceVolume = "data", containerPath = "/rds", readOnly = true }]
      logConfiguration = local.mssql_log_config
    }
  ])

  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "mssql" {
  count = local.mssql_enabled ? 1 : 0

  name                = "${local.name}-mssql-metrics"
  description         = "Runs the SQL Server metrics task"
  schedule_expression = var.mssql_schedule_expression

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "mssql" {
  count = local.mssql_enabled ? 1 : 0

  rule     = aws_cloudwatch_event_rule.mssql[0].name
  arn      = aws_ecs_cluster.monitoring.arn
  role_arn = aws_iam_role.events[0].arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.mssql_metrics[0].arn
    launch_type         = "FARGATE"
    platform_version    = "1.4.0"

    network_configuration {
      subnets          = [local.monitor_subnet_id]
      security_groups  = [aws_security_group.internal.id]
      assign_public_ip = false
    }
  }
}
