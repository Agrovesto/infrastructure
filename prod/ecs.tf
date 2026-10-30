# =============================================================================
# ECS — one Fargate service per dev API (wallet, onboarding, input, moneval,
# serviceprovider), running in the PRIVATE subnets behind the ALB.
#
# Every task gets:
#   PORT          - the container port (contract for the app image)
#   DB_HOST/DB_PORT/DB_NAME - the RDS SQL Server endpoint + its own database
#                        (service name == database name, like dev)
# Bootstrap mode injects DB_USER/DB_PASSWORD from the RDS master secret;
# Vault mode injects that API's AppRole bundle and expects DB credentials in KV.
# =============================================================================

resource "aws_ecs_cluster" "main" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  lifecycle {
    precondition {
      condition     = !var.vault_secrets_enabled || var.enable_vault
      error_message = "vault_secrets_enabled requires enable_vault = true."
    }
  }

  tags = local.tags
}

resource "aws_ecs_task_definition" "services" {
  for_each = var.services

  family                   = "${local.name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  # Graviton (ARM64): ~20% cheaper than x86 Fargate. Images must be built for
  # linux/arm64 — see var.ecs_cpu_architecture.
  runtime_platform {
    cpu_architecture        = var.ecs_cpu_architecture
    operating_system_family = var.ecs_operating_system_family
  }

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = each.value.image
      essential = true

      portMappings = [
        {
          containerPort = each.value.port
          protocol      = "tcp"
        }
      ]

      environment = concat(
        [{ name = "PORT", value = tostring(each.value.port) }],
        [for k, v in each.value.environment : { name = k, value = v }],
        [
          { name = "DB_HOST", value = split(":", aws_db_instance.mssql.endpoint)[0] },
          { name = "DB_PORT", value = tostring(var.mssql_port) },
          # Service name == database name (dev convention).
          { name = "DB_NAME", value = each.key }
        ],
        # Services always know where Vault lives once it exists; they only
        # *need* it after var.vault_secrets_enabled flips the creds source.
        var.enable_vault ? [
          { name = "VAULT_ADDR", value = "https://${var.vault_subdomain}.${var.domain_name}" }
        ] : [],
        var.vault_secrets_enabled ? [
          { name = "VAULT_KV_MOUNT", value = local.vault_kv_mount },
          { name = "VAULT_SECRET_PATH", value = local.vault_service_paths[each.key] },
          { name = "VAULT_AUTH_METHOD", value = "approle" },
          # .NET configuration mapping for { "Vault": { "SecretPath": "..." } }.
          { name = "Vault__SecretPath", value = local.vault_service_paths[each.key] }
        ] : [],
        # OpenTelemetry, sent to Alloy in the monitoring stack's edge task and
        # fanned out to Tempo (traces), Prometheus (metrics) and Loki (logs).
        # Everything but the service name is shared, so it lives in
        # local.otel_environment; OTEL_SERVICE_NAME is what makes a span
        # attributable, and it is the service key — the same string as DB_NAME
        # and as the Route53 subdomain prefix, so a trace, a log line and a
        # database all carry one name.
        #
        # Inert until the image loads/configures an OTel SDK and logging
        # provider (see var.otel). The images are still placeholders; once real
        # ASP.NET images land, traces, metrics and logs can flow without a
        # further infrastructure change or monitoring-stack redeploy.
        var.otel.enabled ? concat(
          [{ name = "OTEL_SERVICE_NAME", value = each.key }],
          local.otel_environment,
        ) : []
      )

      # Bootstrap mode injects the RDS master fields. Once the per-service KV
      # payloads and AppRole credentials are ready, vault_secrets_enabled swaps
      # these for only that API's AppRole credentials from Secrets Manager.
      secrets = var.vault_secrets_enabled && var.enable_vault ? [
        {
          name      = "VAULT_ROLE_ID"
          valueFrom = "${aws_secretsmanager_secret.vault_service_credentials[each.key].arn}:role_id::"
        },
        {
          name      = "VAULT_SECRET_ID"
          valueFrom = "${aws_secretsmanager_secret.vault_service_credentials[each.key].arn}:secret_id::"
        }
      ] : [
        { name = "DB_USER", valueFrom = "${local.mssql_master_secret_arn}:username::" },
        { name = "DB_PASSWORD", valueFrom = "${local.mssql_master_secret_arn}:password::" }
      ]

      # API logs use the in-VPC OTLP receiver on Alloy and are forwarded to Loki.
      # These app containers deliberately have no awslogs logConfiguration.
    }
  ])

  # The ECS agent needs this policy before it can resolve the per-service
  # Secrets Manager AppRole fields at task startup.
  depends_on = [aws_iam_role_policy.ecs_execution_secrets]

  tags = merge(local.tags, { Service = each.key })
}

resource "aws_ecs_service" "services" {
  for_each = var.services

  name            = each.key
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

  deployment_controller {
    type = "ECS"
  }

  # Roll failed deployments back automatically (prod).
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  health_check_grace_period_seconds = 60

  network_configuration {
    # Private subnets only — no public IPs on tasks (CKV_AWS_333 friendly).
    # var.single_az_ecs pins every task to the first AZ (single-AZ for now).
    subnets          = var.single_az_ecs ? [aws_subnet.private[0].id] : aws_subnet.private[*].id
    security_groups = local.ecs_service_security_groups[each.key]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.services[each.key].arn
    container_name   = each.key
    container_port   = each.value.port
  }

  # The HTTPS listener must exist before the service registers targets.
  depends_on = [aws_lb_listener_rule.services]

  # desired_count only seeds the service on first create. Afterwards
  # Application Auto Scaling owns it (see aws_appautoscaling_* below) — without
  # this, every apply would drag the count back to the configured value and
  # undo a scale-out that happened minutes earlier.
  #
  # Caveat: this applies even when ecs_autoscaling_enabled = false. If you turn
  # autoscaling off and want Terraform to drive desired_count again, drop this
  # block (or `terraform apply -replace` the service).
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge(local.tags, { Service = each.key })
}

# =============================================================================
# Autoscaling — one warm task, scale out on load
#
# Why not scale to zero: with 0 tasks the ALB has no healthy target and
# returns 503 — nothing in AWS turns an incoming HTTP request into an ECS
# scale-out. So every service keeps min_capacity = 1 (about $10/mo each at
# 0.25 vCPU / 0.5 GB) and scales up to max_capacity on request load.
#
# Costs nothing to have: the Application Auto Scaling service-linked role
# (AWSServiceRoleForApplicationAutoScaling_ECS) is created by AWS
# automatically, so there are no extra IAM resources here.
#
# Vault is deliberately excluded: raft storage on EFS must have exactly one
# writer, so a second task would corrupt it.
# =============================================================================

resource "aws_appautoscaling_target" "services" {
  for_each = var.ecs_autoscaling_enabled ? var.services : {}

  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.services[each.key].name}"

  min_capacity = var.ecs_autoscaling_min_capacity
  max_capacity = var.ecs_autoscaling_max_capacity
}

resource "aws_appautoscaling_policy" "services" {
  for_each = var.ecs_autoscaling_enabled ? var.services : {}

  name        = "${local.name}-${each.key}-requests"
  policy_type = "TargetTrackingScaling"

  service_namespace  = aws_appautoscaling_target.services[each.key].service_namespace
  scalable_dimension = aws_appautoscaling_target.services[each.key].scalable_dimension
  resource_id        = aws_appautoscaling_target.services[each.key].resource_id

  target_tracking_scaling_policy_configuration {
    # Requests per minute per task. 1000 ≈ 16 rps per task — tune once you
    # have real traffic (CloudWatch: RequestCountPerTarget on each target
    # group). Lower = more tasks, higher latency headroom.
    target_value = var.ecs_autoscaling_requests_per_task

    # React quickly to load, drift back down slowly so a lull doesn't drop
    # tasks you still need.
    scale_in_cooldown  = var.ecs_autoscaling_scale_in_cooldown
    scale_out_cooldown = var.ecs_autoscaling_scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.services[each.key].arn_suffix}"
    }
  }
}
