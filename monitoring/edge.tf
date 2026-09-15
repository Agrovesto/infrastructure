# Edge group: Alloy (OTLP + Loki push gateway), Alertmanager, blackbox-exporter
# and Pushgateway share one Fargate task instead of paying the Fargate minimum
# four times over.
#
#   Alloy          OTLP gRPC/HTTP (4317/4318) -> Tempo | Prometheus | Loki
#                  Loki push API (3100), self-metrics (12345)
#   Alertmanager   alert routing, silences          (9093)
#   blackbox       uptime/TLS probes                (9115)
#   Pushgateway    batch metrics landing point      (9091)
#
# The group registers in Cloud Map as "edge"; the four original DNS names stay
# valid as CNAMEs to it (cloudmap.tf), so nothing that talks to them changes.

locals {
  edge_state_components = ["alloy", "alertmanager", "blackbox"]

  edge_init_container = {
    name      = "config"
    image     = local.images.awscli
    essential = false
    user      = "0"
    environment = [
      { name = "AWS_REGION", value = var.aws_region },
      { name = "CONFIG_BUCKET", value = aws_s3_bucket.config.bucket },
    ]
    command = ["/bin/sh", "-c", join("\n", concat(
      ["set -euo pipefail"],
      [for component in local.edge_state_components :
        "mkdir -p /config-${component}/config\naws s3 sync \"s3://$CONFIG_BUCKET/config\" /config-${component}/config --delete --region \"$AWS_REGION\""
      ],
    ))]
    mountPoints = [for component in local.edge_state_components : {
      sourceVolume  = "data-${component}"
      containerPath = "/config-${component}"
      readOnly      = false
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.monitoring.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "edge-config"
      }
    }
  }
}

resource "aws_ecs_task_definition" "edge" {
  family                   = "${local.name}-edge"
  cpu                      = local.sizing.edge.cpu
  memory                   = local.sizing.edge.memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  dynamic "volume" {
    for_each = toset(local.edge_state_components)

    content {
      name = "data-${volume.key}"

      efs_volume_configuration {
        file_system_id     = aws_efs_file_system.monitoring.id
        transit_encryption = "ENABLED"

        authorization_config {
          access_point_id = aws_efs_access_point.monitoring[volume.key].id
        }
      }
    }
  }

  container_definitions = jsonencode([
    local.edge_init_container,
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
        { name = "alloy-loki-push", containerPort = 3100, protocol = "tcp" },
        { name = "alloy-otlp-grpc", containerPort = 4317, protocol = "tcp" },
        { name = "alloy-otlp-http", containerPort = 4318, protocol = "tcp" },
        { name = "alloy-http", containerPort = 12345, protocol = "tcp" },
      ]

      mountPoints = [{ sourceVolume = "data-alloy", containerPath = "/alloy", readOnly = false }]

      logConfiguration = local.log_config.alloy
    },
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

      portMappings = [{ name = "alertmanager-http", containerPort = 9093, protocol = "tcp" }]

      mountPoints = [{ sourceVolume = "data-alertmanager", containerPath = "/alertmanager", readOnly = false }]

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:9093/-/healthy > /dev/null || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 30
      }

      logConfiguration = local.log_config.alertmanager
    },
    {
      name      = "blackbox"
      image     = local.images.blackbox
      essential = true
      user      = "65534"

      command = ["--config.file=/blackbox/config/blackbox.yml"]

      portMappings = [{ name = "blackbox-http", containerPort = 9115, protocol = "tcp" }]

      mountPoints = [{ sourceVolume = "data-blackbox", containerPath = "/blackbox", readOnly = false }]

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:9115/-/healthy > /dev/null || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 15
      }

      logConfiguration = local.log_config.blackbox
    },
    {
      name      = "pushgateway"
      image     = local.images.pushgateway
      essential = true
      user      = "65534"

      command = ["--web.listen-address=:9091"]

      portMappings = [{ name = "pushgateway-http", containerPort = 9091, protocol = "tcp" }]

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:9091/-/healthy > /dev/null || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 15
      }

      logConfiguration = local.log_config.pushgateway
    },
  ])

  tags = local.tags
}

resource "aws_ecs_service" "edge" {
  name            = "edge"
  cluster         = aws_ecs_cluster.monitoring.id
  task_definition = aws_ecs_task_definition.edge.arn
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
    registry_arn = aws_service_discovery_service.monitoring["edge"].arn
  }

  tags = local.tags
}
