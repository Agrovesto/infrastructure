resource "aws_ecs_task_definition" "prometheus" {
  family                   = "${local.name}-prometheus"
  cpu                      = local.sizing.prometheus.cpu
  memory                   = local.sizing.prometheus.memory
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
        access_point_id = aws_efs_access_point.monitoring["prometheus"].id
      }
    }
  }

  # The init container mounts the volume at /config and writes the SSM-rendered
  # files into <volume>/config, which is why Prometheus finds them under
  # /prometheus/config. State (the TSDB) lives beside them in /prometheus/data.
  container_definitions = jsonencode([
    local.init_containers.prometheus,
    {
      name      = "prometheus"
      image     = local.images.prometheus
      essential = true
      dependsOn = [{ containerName = "config", condition = "SUCCESS" }]
      user      = "65534"

      command = [
        "--config.file=/prometheus/config/prometheus.yml",
        "--storage.tsdb.path=/prometheus/data",
        "--storage.tsdb.retention.time=${var.metrics_retention}",
        "--storage.tsdb.retention.size=${var.metrics_retention_size}",
        "--web.listen-address=0.0.0.0:9090",
        "--web.enable-lifecycle",
        "--web.enable-remote-write-receiver",
      ]

      portMappings = [{ name = "http", containerPort = 9090, protocol = "tcp" }]

      mountPoints = [{ sourceVolume = "data", containerPath = "/prometheus", readOnly = false }]

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:9090/-/healthy > /dev/null || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 60
      }

      logConfiguration = local.log_config.prometheus
    }
  ])

  tags = local.tags
}

resource "aws_ecs_service" "prometheus" {
  name            = "prometheus"
  cluster         = aws_ecs_cluster.monitoring.id
  task_definition = aws_ecs_task_definition.prometheus.arn
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
    registry_arn = aws_service_discovery_service.monitoring["prometheus"].arn
  }

  tags = local.tags
}
