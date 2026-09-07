locals {
  active_services   = var.services_enabled ? var.services : {}
  database_services = { for name, s in var.services : name => s if s.database_key != null }
  task_trust = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
  service_secret_arns = { for name, s in var.services : name => distinct(concat(
    s.database_key == null ? [] : [var.database_secret_arns[s.database_key]],
    [for arn in values(s.secrets) : join(":", slice(split(":", arn), 0, 7))]
  )) }
}
resource "aws_ecs_cluster" "this" {
  name = var.name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
resource "aws_security_group" "service" {
  for_each    = var.services
  name        = "${var.name}-${each.key}"
  description = "Private ECS ${each.key}; ingress only from the ALB"
  vpc_id      = var.vpc_id
}
resource "aws_vpc_security_group_ingress_rule" "service" {
  for_each                     = var.services
  security_group_id            = aws_security_group.service[each.key].id
  referenced_security_group_id = var.alb_security_group_id
  description                  = "ALB to ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
}
resource "aws_vpc_security_group_egress_rule" "alb" {
  for_each                     = var.services
  security_group_id            = var.alb_security_group_id
  referenced_security_group_id = aws_security_group.service[each.key].id
  description                  = "ALB to ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
}
resource "aws_vpc_security_group_egress_rule" "https" {
  for_each          = var.services
  security_group_id = aws_security_group.service[each.key].id
  description       = "HTTPS via NAT for ECR, logs, secrets and external APIs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
resource "aws_vpc_security_group_egress_rule" "database" {
  for_each                     = local.database_services
  security_group_id            = aws_security_group.service[each.key].id
  referenced_security_group_id = var.database_security_group_id
  description                  = "SQL Server for ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = 1433
  to_port                      = 1433
}
resource "aws_cloudwatch_log_group" "service" {
  for_each          = var.services
  name              = "/${var.name}/ecs/${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}
resource "aws_iam_role" "execution" {
  for_each             = var.services
  name                 = "${var.name}-${each.key}-execution"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy   = local.task_trust
}
resource "aws_iam_role_policy" "execution" {
  for_each = var.services
  role     = aws_iam_role.execution[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow", Action = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"], Resource = var.ecr_repository_arns },
      { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.service[each.key].arn}:*" }
      ], length(local.service_secret_arns[each.key]) == 0 ? [] : [
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = local.service_secret_arns[each.key] },
      { Effect = "Allow", Action = ["kms:Decrypt"], Resource = var.kms_key_arn }
    ])
  })
}
# No shared application role, no permission to read another API's credentials,
# and no AWS API permissions unless deliberately added to a particular role.
resource "aws_iam_role" "task" {
  for_each             = var.services
  name                 = "${var.name}-${each.key}-task"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy   = local.task_trust
}
resource "aws_ecs_task_definition" "service" {
  for_each                 = var.services
  family                   = "${var.name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(each.value.cpu)
  memory                   = tostring(each.value.memory)
  execution_role_arn       = aws_iam_role.execution[each.key].arn
  task_role_arn            = aws_iam_role.task[each.key].arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = jsonencode([merge({
    name                   = each.key
    image                  = each.value.image
    essential              = true
    user                   = each.value.user
    readonlyRootFilesystem = true
    linuxParameters        = { capabilities = { drop = ["ALL"] }, initProcessEnabled = true }
    portMappings           = [{ containerPort = each.value.port, protocol = "tcp" }]
    environment = [for k, v in merge(each.value.environment, each.value.database_key == null ? {} : {
      DB_HOST    = var.database_host, DB_PORT = "1433", DB_NAME = var.databases[each.value.database_key]
      DB_ENCRYPT = "true", DB_TRUST_SERVER_CERTIFICATE = "false"
    }) : { name = k, value = v }]
    secrets = concat(
      [for k, v in each.value.secrets : { name = k, valueFrom = v }],
      each.value.database_key == null ? [] : [
        { name = "DB_USER", valueFrom = "${var.database_secret_arns[each.value.database_key]}:username::" },
        { name = "DB_PASSWORD", valueFrom = "${var.database_secret_arns[each.value.database_key]}:password::" }
      ]
    )
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.service[each.key].name, awslogs-region = var.region
        awslogs-stream-prefix = each.key, mode = "non-blocking", max-buffer-size = "25m"
      }
    }
    }, length(each.value.health_check_command) == 0 ? {} : {
    healthCheck = { command = each.value.health_check_command, interval = 30, timeout = 5, retries = 3, startPeriod = 60 }
  })])
}
resource "aws_ecs_service" "this" {
  for_each                           = local.active_services
  name                               = each.key
  cluster                            = aws_ecs_cluster.this.id
  task_definition                    = aws_ecs_task_definition.service[each.key].arn
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  desired_count                      = each.value.min_count
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 120
  wait_for_steady_state              = true
  enable_execute_command             = false
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  availability_zone_rebalancing      = "ENABLED"
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.service[each.key].id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.this[each.key].arn
    container_name   = each.key
    container_port   = each.value.port
  }
  lifecycle {
    ignore_changes = [desired_count]
  }
  timeouts {
    create = "30m"
    update = "30m"
  }
  depends_on = [aws_lb_listener_rule.this, aws_iam_role_policy.execution]
}
resource "aws_appautoscaling_target" "this" {
  for_each           = local.active_services
  min_capacity       = each.value.min_count
  max_capacity       = each.value.max_count
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
resource "aws_appautoscaling_policy" "cpu" {
  for_each           = local.active_services
  name               = "${var.name}-${each.key}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.this[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[each.key].service_namespace
  target_tracking_scaling_policy_configuration {
    target_value       = 60
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
resource "aws_appautoscaling_policy" "memory" {
  for_each           = local.active_services
  name               = "${var.name}-${each.key}-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.this[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[each.key].service_namespace
  target_tracking_scaling_policy_configuration {
    target_value       = 75
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}
resource "aws_cloudwatch_log_group" "insights" {
  name              = "/aws/ecs/containerinsights/${var.name}/performance"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}
