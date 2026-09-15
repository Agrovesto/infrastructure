resource "aws_ecs_task_definition" "alertmanager" {
  family                   = "${local.name}-alertmanager"
  cpu                      = local.sizing.alertmanager.cpu
  memory                   = local.sizing.alertmanager.memory
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
        access_point_id = aws_efs_access_point.monitoring["alertmanager"].id
      }
    }
  }

  container_definitions = jsonencode([
    merge(local.init_container, {
      environment = concat(
        local.init_container.environment,
        [{ name = "PARAM_PATH", value = "${local.param}/alertmanager" }]
      )
    }),
    {
      name      = "alertmanager"
      image     = local.images.alertmanager
      essential = true
      user      = "65534"

      command = [
        "--config.file=/alertmanager/config/alertmanager.yml",
        "--storage.path=/alertmanager/data",
        "--web.listen-address=0.0.0.0:9093",
        "--log.level=warn",
      ]

      portMappings = [{ name = "http", containerPort = 9093, protocol = "tcp" }]

      mountPoints = [{ sourceVolume = "data", containerPath = "/alertmanager", readOnly = false }]

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:9093/-/healthy > /dev/null || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 30
      }

      logConfiguration = local.log_config.alertmanager
    }
  ])

  tags = local.tags
}

resource "aws_ecs_service" "alertmanager" {
  name            = "alertmanager"
  cluster         = aws_ecs_cluster.monitoring.id
  task_definition = aws_ecs_task_definition.alertmanager.arn
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
    registry_arn = aws_service_discovery_service.monitoring["alertmanager"].arn
  }

  tags = local.tags
}
