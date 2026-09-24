resource "aws_ecs_task_definition" "grafana" {
  family                   = "${local.name}-grafana"
  cpu                      = local.sizing.grafana.cpu
  memory                   = local.sizing.grafana.memory
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
        access_point_id = aws_efs_access_point.monitoring["grafana"].id
      }
    }
  }

  container_definitions = jsonencode([
    local.init_containers.grafana,
    {
      name      = "grafana"
      image     = local.images.grafana
      essential = true
      dependsOn = [{ containerName = "config", condition = "SUCCESS" }]
      user      = "472"

      portMappings = [{ name = "http", containerPort = 3000, protocol = "tcp" }]
      mountPoints  = [{ sourceVolume = "data", containerPath = "/var/lib/grafana", readOnly = false }]

      environment = concat(
        [
          { name = "GF_SERVER_HTTP_PORT", value = "3000" },
          { name = "GF_SERVER_ROOT_URL", value = "https://${local.grafana_host}" },
          { name = "GF_SECURITY_ADMIN_USER", value = var.grafana_admin_user },
          { name = "GF_USERS_ALLOW_SIGN_UP", value = "false" },
          { name = "GF_USERS_AUTO_ASSIGN_ORG_ROLE", value = "Viewer" },
          { name = "GF_ANALYTICS_REPORTING_ENABLED", value = "false" },
          { name = "GF_ANALYTICS_CHECK_FOR_UPDATES", value = "false" },
          { name = "GF_ANALYTICS_CHECK_FOR_PLUGIN_UPDATES", value = "false" },
          { name = "GF_PATHS_PROVISIONING", value = "/var/lib/grafana/config/provisioning" },
          { name = "GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH", value = "/var/lib/grafana/config/dashboards/platform.json" },
          { name = "GF_LOG_LEVEL", value = "warn" },
        ],
        local.grafana_github_sso_enabled ? [
          { name = "GF_AUTH_GITHUB_ENABLED", value = "true" },
          { name = "GF_AUTH_GITHUB_SCOPES", value = "user:email,read:org" },
          { name = "GF_AUTH_GITHUB_ALLOWED_ORGANIZATIONS", value = join(" ", var.grafana_github_organizations) },
          { name = "GF_AUTH_GITHUB_ALLOW_SIGN_UP", value = tostring(var.grafana_github_allow_sign_up) },
          { name = "GF_AUTH_GITHUB_ROLE_ATTRIBUTE_PATH", value = local.grafana_github_role_attribute_path },
          { name = "GF_AUTH_GITHUB_ROLE_ATTRIBUTE_STRICT", value = "true" },
          { name = "GF_AUTH_GITHUB_SKIP_ORG_ROLE_SYNC", value = "false" },
          # Admin is an organization role, never unrestricted server admin.
          { name = "GF_AUTH_GITHUB_ALLOW_ASSIGN_GRAFANA_ADMIN", value = "false" },
          # Force a new task revision when either SecureString is rotated; ECS
          # resolves secret values only when a task starts.
          { name = "GITHUB_OAUTH_CONFIG_VERSION", value = join("-", [tostring(aws_ssm_parameter.grafana_github_client_id[0].version), tostring(aws_ssm_parameter.grafana_github_client_secret[0].version)]) },
          # Keep the local admin form available as a break-glass login.
          { name = "GF_AUTH_GITHUB_AUTO_LOGIN", value = "false" },
        ] : []
      )

      secrets = concat(
        [{
          name      = "GF_SECURITY_ADMIN_PASSWORD"
          valueFrom = aws_ssm_parameter.grafana_admin_password.arn
        }],
        local.grafana_github_sso_enabled ? [
          {
            name      = "GF_AUTH_GITHUB_CLIENT_ID"
            valueFrom = aws_ssm_parameter.grafana_github_client_id[0].arn
          },
          {
            name      = "GF_AUTH_GITHUB_CLIENT_SECRET"
            valueFrom = aws_ssm_parameter.grafana_github_client_secret[0].arn
          },
        ] : []
      )

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:3000/api/health > /dev/null || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = local.log_config.grafana
    }
  ])

  lifecycle {
    precondition {
      condition     = local.grafana_github_configuration_valid
      error_message = "Grafana GitHub SSO requires both the client ID and client secret, or both must be empty."
    }

    precondition {
      condition     = !alltrue(local.grafana_github_credentials_set) || local.grafana_github_team_organizations_valid
      error_message = "Every production Grafana GitHub team-role organization must also be present in grafana_github_organizations."
    }
  }

  tags = local.tags
}

resource "aws_ecs_service" "grafana" {
  name            = "grafana"
  cluster         = aws_ecs_cluster.monitoring.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  enable_execute_command = true
  depends_on = [
    aws_ecs_service.prometheus,
    aws_ecs_service.loki,
    aws_ecs_service.tempo,
    aws_ecs_service.edge
  ]

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [local.monitor_subnet_id]
    security_groups  = [aws_security_group.grafana.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.monitoring["grafana"].arn
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  tags = local.tags
}

# Published on the existing prod ALB under its own host header: no second load
# balancer, and the wildcard certificate already covers the name.
resource "aws_lb_target_group" "grafana" {
  name                 = "${local.name}-grafana"
  port                 = 3000
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = data.aws_vpc.prod.id
  deregistration_delay = 30

  health_check {
    path                = "/api/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(local.tags, { Name = "${local.name}-grafana" })
}

resource "aws_lb_listener_rule" "grafana" {
  listener_arn = data.aws_lb_listener.https.arn
  priority     = var.grafana_listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }

  condition {
    host_header {
      values = [local.grafana_host]
    }
  }

  # Optional client-IP allowlist, enforced at the load balancer because the ALB
  # itself is internet-facing.
  condition {
    source_ip {
      values = length(var.grafana_allowed_cidrs) > 0 ? var.grafana_allowed_cidrs : [data.aws_vpc.prod.cidr_block]
    }
  }

  tags = merge(local.tags, { Name = "${local.name}-grafana" })
}

resource "aws_route53_record" "grafana" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.grafana_host
  type    = "A"

  alias {
    name                   = data.aws_lb.main.dns_name
    zone_id                = data.aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
