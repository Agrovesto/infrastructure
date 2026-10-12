# ECS platform monitoring without Container Insights or CloudWatch dashboards:
# a scheduled Fargate task reads the ECS API, ships service logs into Loki,
# republishes the free basic CloudWatch metrics as Prometheus series and parses
# the ALB access logs out of S3, pushing its own state to Pushgateway.

locals {
  collector_enabled = var.enable_ecs_monitoring

  # Both extra collectors ride the ECS collector task: same schedule, same EFS
  # checkpoint directory, same task role, and no second Fargate task to run.
  cloudwatch_metrics_enabled = local.collector_enabled && var.enable_cloudwatch_metrics
  alb_log_shipping_enabled   = local.collector_enabled && var.enable_alb_log_shipping

  ecs_cluster    = var.ecs_cluster_name != "" ? var.ecs_cluster_name : "${var.project}-${var.environment}"
  ecs_log_prefix = var.ecs_log_group_prefix != "" ? var.ecs_log_group_prefix : "/ecs/${var.project}-${var.environment}"

  # prod/alb.tf names the access log bucket <project>-<environment>-alb-logs-<account id>.
  alb_logs_bucket = var.alb_access_logs_bucket != "" ? var.alb_access_logs_bucket : "${var.project}-${var.environment}-alb-logs-${data.aws_caller_identity.current.account_id}"

  # Target groups are named <project>-<environment>-<service>, so stripping this
  # prefix gives the ALB series and log streams the same `service` value the ECS
  # series carry, and a dashboard can put the two side by side.
  service_prefix = "${var.project}-${var.environment}-"

  collector_scripts = concat(
    ["python /collector/config/ecs_metrics.py"],
    var.enable_ecs_log_shipping ? ["python /collector/config/ecs_logs.py"] : [],
    local.cloudwatch_metrics_enabled ? ["python /collector/config/cw_metrics.py"] : [],
    local.alb_log_shipping_enabled ? ["python /collector/config/alb_logs.py"] : [],
  )

  # "; " and not "&& ": every script reports its own failure through Pushgateway
  # and exits 0, so one collector having a bad run must not stop the others. The
  # dependency install still has to succeed, or nothing below can run at all.
  collector_command = join("; ", concat(["pip install --quiet --no-cache-dir boto3 || exit 1"], local.collector_scripts))

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
    local.init_containers.collector,
    {
      name      = "collector"
      image     = local.images.collector
      essential = true
      dependsOn = [{ containerName = "config", condition = "SUCCESS" }]

      command = ["sh", "-c", local.collector_command]

      environment = concat([
        { name = "AWS_REGION", value = var.aws_region },
        { name = "ECS_CLUSTER", value = local.ecs_cluster },
        { name = "LOG_GROUP_PREFIX", value = local.ecs_log_prefix },
        { name = "LOKI_URL", value = local.endpoints.loki },
        { name = "PUSHGATEWAY_URL", value = local.endpoints.pushgateway },
        { name = "STATE_FILE", value = "/collector/state/ecs_logs.json" },
        { name = "LOOKBACK_MINUTES", value = tostring(var.ecs_log_lookback_minutes) },
        { name = "SERVICE_PREFIX", value = local.service_prefix },
        ], local.cloudwatch_metrics_enabled ? [
        # cw_metrics.py checkpoints to CW_STATE_FILE (its default is fine, the
        # STATE_FILE above belongs to the ECS log shipper).
        { name = "ALB_ARN_SUFFIX", value = data.aws_lb.main.arn_suffix },
        { name = "METRIC_DELAY_SECONDS", value = tostring(var.cloudwatch_metric_delay_seconds) },
        { name = "MAX_WINDOW_MINUTES", value = tostring(var.cloudwatch_max_window_minutes) },
        ] : [], local.alb_log_shipping_enabled ? [
        { name = "ALB_LOGS_BUCKET", value = local.alb_logs_bucket },
        { name = "ALB_LOGS_PREFIX", value = var.alb_access_logs_prefix },
        { name = "ACCOUNT_ID", value = data.aws_caller_identity.current.account_id },
        { name = "MAX_OBJECTS_PER_RUN", value = tostring(var.alb_log_max_objects_per_run) },
      ] : [])

      mountPoints      = [{ sourceVolume = "data", containerPath = "/collector", readOnly = false }]
      logConfiguration = local.collector_log_config
    }
  ])

  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "collector" {
  count = local.collector_enabled ? 1 : 0

  name                = "${local.name}-ecs-collector"
  description         = "Runs the ECS, CloudWatch metric and ALB access log collectors"
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
