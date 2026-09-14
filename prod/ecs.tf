# =============================================================================
# ECS — one Fargate service per dev API (wallet, onboarding, input, moneval,
# serviceprovider), running in the PRIVATE subnets behind the ALB.
#
# Every task gets:
#   PORT          - the container port (contract for the app image)
#   DB_HOST/DB_PORT/DB_NAME - the RDS SQL Server endpoint + its own database
#                        (service name == database name, like dev)
#   DB_USER/DB_PASSWORD   - injected from Secrets Manager (RDS master secret)
# =============================================================================

resource "aws_ecs_cluster" "main" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = local.tags
}

# CloudWatch default encryption (AWS-owned key) is enough for service logs - mirrors checkov CKV_AWS_158 skip.
#trivy:ignore:AVD-AWS-0017
resource "aws_cloudwatch_log_group" "services" {
  for_each = var.services

  name              = "/ecs/${local.name}/${each.key}"
  retention_in_days = var.log_retention_days

  tags = merge(local.tags, { Service = each.key })
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
        var.enable_vault ? [{ name = "VAULT_ADDR", value = "https://${var.vault_subdomain}.${var.domain_name}" }] : []
      )

      # Bootstrap mode: DB creds injected from Secrets Manager. Once Vault is
      # initialized (see vault.tf) set vault_secrets_enabled = true and these
      # go away — the app reads kv/<service> from Vault instead.
      secrets = var.vault_secrets_enabled ? [] : [
        { name = "DB_USER", valueFrom = "${aws_secretsmanager_secret.mssql_master.arn}:username::" },
        { name = "DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.mssql_master.arn}:password::" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.services[each.key].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = merge(local.tags, { Service = each.key })
}

resource "aws_ecs_service" "services" {
  for_each = var.services

  name            = each.key
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

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
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.services[each.key].arn
    container_name   = each.key
    container_port   = each.value.port
  }

  # The HTTPS listener must exist before the service registers targets.
  depends_on = [aws_lb_listener.https]

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
