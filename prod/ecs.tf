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
        ]
      )

      secrets = [
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
    subnets          = aws_subnet.private[*].id
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

  tags = merge(local.tags, { Service = each.key })
}
