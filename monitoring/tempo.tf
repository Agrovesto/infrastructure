# Tempo, like Loki, ships an image without a shell or wget: no container health check.

resource "aws_ecs_task_definition" "tempo" {
  count = var.enable_traces ? 1 : 0

  family                   = "${local.name}-tempo"
  cpu                      = local.sizing.tempo.cpu
  memory                   = local.sizing.tempo.memory
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
        access_point_id = aws_efs_access_point.monitoring["tempo"].id
      }
    }
  }

  container_definitions = jsonencode([
    merge(local.init_container, {
      environment = concat(
        local.init_container.environment,
        [{ name = "PARAM_PATH", value = "${local.param}/tempo" }]
      )
    }),
    {
      name      = "tempo"
      image     = local.images.tempo
      essential = true
      user      = "10001"

      command = [
        "-config.file=/tempo/config/config.yml",
        "-target=all",
      ]

      portMappings = [
        { name = "http", containerPort = 3200, protocol = "tcp" },
        { name = "otlp-grpc", containerPort = 4317, protocol = "tcp" },
        { name = "otlp-http", containerPort = 4318, protocol = "tcp" },
      ]

      mountPoints = [{ sourceVolume = "data", containerPath = "/tempo", readOnly = false }]

      logConfiguration = local.log_config.tempo
    }
  ])

  tags = local.tags
}

resource "aws_ecs_service" "tempo" {
  count = var.enable_traces ? 1 : 0

  name            = "tempo"
  cluster         = aws_ecs_cluster.monitoring.id
  task_definition = aws_ecs_task_definition.tempo[0].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  enable_execute_command = true

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
    registry_arn = aws_service_discovery_service.monitoring["tempo"].arn
  }

  tags = local.tags
}
