# Ingestion gateway: the single address services and collectors send telemetry to.
#
#   OTLP gRPC/HTTP (4317/4318)  ->  Tempo (traces) | Prometheus (metrics via remote write) | Loki (logs)
#   Loki push API (3100)        ->  Loki (logs from Fluent Bit/FireLens or the app itself)
#
# It runs on Fargate Spot when var.use_fargate_spot is set: an interruption only
# delays ingestion, it does not lose stored data.

resource "aws_ecs_task_definition" "alloy" {
  family                   = "${local.name}-alloy"
  cpu                      = local.sizing.alloy.cpu
  memory                   = local.sizing.alloy.memory
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
        access_point_id = aws_efs_access_point.monitoring["alloy"].id
      }
    }
  }

  # No container health check: the Alloy image ships no shell or wget.
  container_definitions = jsonencode([
    merge(local.init_container, {
      environment = concat(
        local.init_container.environment,
        [{ name = "PARAM_PATH", value = "${local.param}/alloy" }]
      )
    }),
    {
      name      = "alloy"
      image     = local.images.alloy
      essential = true

      command = [
        "run",
        "/alloy/config/config.alloy",
        "--server.http.listen-addr=0.0.0.0:12345",
        "--disable-reporting",
      ]

      portMappings = [
        { name = "loki-push", containerPort = 3100, protocol = "tcp" },
        { name = "otlp-grpc", containerPort = 4317, protocol = "tcp" },
        { name = "otlp-http", containerPort = 4318, protocol = "tcp" },
        { name = "http", containerPort = 12345, protocol = "tcp" },
      ]

      mountPoints = [{ sourceVolume = "data", containerPath = "/alloy", readOnly = false }]

      logConfiguration = local.log_config.alloy
    }
  ])

  tags = local.tags
}

resource "aws_ecs_service" "alloy" {
  name            = "alloy"
  cluster         = aws_ecs_cluster.monitoring.id
  task_definition = aws_ecs_task_definition.alloy.arn
  desired_count   = 1

  launch_type = var.use_fargate_spot ? null : "FARGATE"

  dynamic "capacity_provider_strategy" {
    for_each = var.use_fargate_spot ? [1] : []

    content {
      capacity_provider = "FARGATE_SPOT"
      weight            = 1
    }
  }

  enable_execute_command = true
  depends_on = [
    aws_ecs_service.prometheus,
    aws_ecs_service.loki,
    aws_ecs_service.tempo
  ]

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [local.monitor_subnet_id]
    security_groups  = [aws_security_group.internal.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.monitoring["alloy"].arn
  }

  tags = local.tags
}
