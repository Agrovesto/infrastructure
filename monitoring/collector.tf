# ECS platform monitoring without Container Insights or CloudWatch metrics:
# a scheduled Fargate task reads the ECS API and ships service logs into Loki,
# pushing its own state to Pushgateway for Prometheus.

locals {
  collector_enabled = var.enable_ecs_monitoring

  ecs_cluster       = var.ecs_cluster_name != "" ? var.ecs_cluster_name : "${var.project}-${var.environment}"
  ecs_log_prefix    = var.ecs_log_group_prefix != "" ? var.ecs_log_group_prefix : "/ecs/${var.project}-${var.environment}"
  collector_scripts = var.enable_ecs_log_shipping ? ["python /collector/config/ecs_metrics.py", "python /collector/config/ecs_logs.py"] : ["python /collector/config/ecs_metrics.py"]

  collector_command = join(" && ", concat(["pip install --quiet --no-cache-dir boto3"], local.collector_scripts))

  collector_log_config = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.monitoring.name
      awslogs-region        = var.aws_region
      awslogs-stream-prefix = "collector"
    }
  }
}

resource "aws_ecs_task_definition" "collector" {
  count = local.collector_enabled ? 1 : 0

  family                   = "${local.name}-ecs-collector"
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
        access_point_id = aws_efs_access_point.monitoring["collector"].id
      }
    }
  }

  container_definitions = jsonencode([
    local.init_container,
    {
      name      = "collector"
      image     = local.images.collector
      essential = true

      command = ["sh", "-c", local.collector_command]

      environment = [
        { name = "AWS_REGION", value = var.aws_region },
        { name = "ECS_CLUSTER", value = local.ecs_cluster },
        { name = "LOG_GROUP_PREFIX", value = local.ecs_log_prefix },
        { name = "LOKI_URL", value = local.endpoints.loki },
        { name = "PUSHGATEWAY_URL", value = local.endpoints.pushgateway },
        { name = "STATE_FILE", value = "/collector/state/ecs_logs.json" },
        { name = "LOOKBACK_MINUTES", value = tostring(var.ecs_log_lookback_minutes) },
      ]

      mountPoints      = [{ sourceVolume = "data", containerPath = "/collector", readOnly = false }]
      logConfiguration = local.collector_log_config
    }
  ])

  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "collector" {
  count = local.collector_enabled ? 1 : 0

  name                = "${local.name}-ecs-collector"
  description         = "Runs the ECS metrics and log collector"
  schedule_expression = var.collector_schedule_expression

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "collector" {
  count = local.collector_enabled ? 1 : 0

  rule     = aws_cloudwatch_event_rule.collector[0].name
  arn      = aws_ecs_cluster.monitoring.arn
  role_arn = aws_iam_role.events[0].arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.collector[0].arn
    launch_type         = "FARGATE"
    platform_version    = "1.4.0"

    network_configuration {
      subnets          = [local.monitor_subnet_id]
      security_groups  = [aws_security_group.internal.id]
      assign_public_ip = false
    }
  }
}
