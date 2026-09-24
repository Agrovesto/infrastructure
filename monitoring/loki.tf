# Loki's image ships neither a shell nor wget, so there is no container health
# check: the service-level deployment circuit breaker covers failures.

resource "aws_ecs_task_definition" "loki" {
  count = var.enable_logs ? 1 : 0

  family                   = "${local.name}-loki"
  cpu                      = local.sizing.loki.cpu
  memory                   = local.sizing.loki.memory
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
        access_point_id = aws_efs_access_point.monitoring["loki"].id
      }
    }
  }

  container_definitions = jsonencode([
    local.init_containers.loki,
    {
      name      = "loki"
      image     = local.images.loki
      essential = true
      dependsOn = [{ containerName = "config", condition = "SUCCESS" }]
      user      = "10001"

      command = [
        "-config.file=/loki/config/config.yml",
        "-target=all",
      ]

      portMappings = [{ name = "http", containerPort = 3100, protocol = "tcp" }]

      mountPoints = [{ sourceVolume = "data", containerPath = "/loki", readOnly = false }]

      logConfiguration = local.log_config.loki
    }
  ])

  tags = local.tags
}

resource "aws_ecs_service" "loki" {
  count = var.enable_logs ? 1 : 0

  name            = "loki"
  cluster         = aws_ecs_cluster.monitoring.id
  task_definition = aws_ecs_task_definition.loki[0].arn
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
    registry_arn = aws_service_discovery_service.monitoring["loki"].arn
  }

  tags = local.tags
}
