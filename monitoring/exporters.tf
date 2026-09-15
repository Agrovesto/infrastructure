# --- blackbox exporter: uptime/TLS probing of the public endpoints -----------------

resource "aws_ecs_task_definition" "blackbox" {
  family                   = "${local.name}-blackbox"
  cpu                      = local.sizing.blackbox.cpu
  memory                   = local.sizing.blackbox.memory
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
        access_point_id = aws_efs_access_point.monitoring["blackbox"].id
      }
    }
  }

  container_definitions = jsonencode([
    local.init_container,
    {
      name      = "blackbox"
      image     = local.images.blackbox
      essential = true
      user      = "65534"

      command = ["--config.file=/blackbox/config/blackbox.yml"]

      portMappings = [{ name = "http", containerPort = 9115, protocol = "tcp" }]
      mountPoints  = [{ sourceVolume = "data", containerPath = "/blackbox", readOnly = false }]

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:9115/-/healthy > /dev/null || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 15
      }

      logConfiguration = local.log_config.blackbox
    }
  ])

  tags = local.tags
}

resource "aws_ecs_service" "blackbox" {
  name            = "blackbox"
  cluster         = aws_ecs_cluster.monitoring.id
  task_definition = aws_ecs_task_definition.blackbox.arn
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
    registry_arn = aws_service_discovery_service.monitoring["blackbox"].arn
  }

  tags = local.tags
}

# --- pushgateway: batch metrics (the daily cost/budget job) ------------------------

resource "aws_ecs_task_definition" "pushgateway" {
  family                   = "${local.name}-pushgateway"
  cpu                      = local.sizing.pushgateway.cpu
  memory                   = local.sizing.pushgateway.memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  # Metrics live in memory: a restart only means the next daily push repopulates
  # them, and the CostReportStale alert covers a job that stops running.
  container_definitions = jsonencode([{
    name      = "pushgateway"
    image     = local.images.pushgateway
    essential = true
    user      = "65534"

    command = ["--web.listen-address=:9091"]

    portMappings = [{ name = "http", containerPort = 9091, protocol = "tcp" }]

    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:9091/-/healthy > /dev/null || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 15
    }

    logConfiguration = local.log_config.pushgateway
  }])

  tags = local.tags
}

resource "aws_ecs_service" "pushgateway" {
  name            = "pushgateway"
  cluster         = aws_ecs_cluster.monitoring.id
  task_definition = aws_ecs_task_definition.pushgateway.arn
  desired_count   = 1

  launch_type = var.use_fargate_spot ? null : "FARGATE"

  dynamic "capacity_provider_strategy" {
    for_each = var.use_fargate_spot ? [1] : []

    content {
      capacity_provider = "FARGATE_SPOT"
      weight            = 1
    }
  }

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
    registry_arn = aws_service_discovery_service.monitoring["pushgateway"].arn
  }

  tags = local.tags
}
