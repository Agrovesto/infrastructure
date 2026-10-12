# Private Amazon MQ; the public management hostname reaches only a restricted
# HTTPS proxy, never the broker directly. No admin secret is injected into apps.
resource "random_password" "rabbitmq" {
  count   = var.rabbitmq.enabled ? 1 : 0
  length  = 40
  special = false
}

resource "aws_secretsmanager_secret" "rabbitmq" {
  count                   = var.rabbitmq.enabled ? 1 : 0
  name                    = "${local.name}/rabbitmq-admin"
  recovery_window_in_days = 30
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "rabbitmq" {
  count     = var.rabbitmq.enabled ? 1 : 0
  secret_id = aws_secretsmanager_secret.rabbitmq[0].id
  secret_string = jsonencode({
    username = "nomaos-admin"
    password = random_password.rabbitmq[0].result
  })
}

resource "aws_security_group" "rabbitmq" {
  count       = var.rabbitmq.enabled ? 1 : 0
  name        = "${local.name}-rabbitmq"
  description = "Private RabbitMQ: TLS AMQP from apps, HTTPS only from management proxy"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "TLS AMQP from ECS apps"
    from_port       = 5671
    to_port         = 5671
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
  ingress {
    description     = "Management HTTPS from dedicated proxy"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.rabbitmq_proxy[0].id]
  }
  tags = local.tags
}

resource "aws_mq_broker" "rabbitmq" {
  count                      = var.rabbitmq.enabled ? 1 : 0
  broker_name                = "${local.name}-rabbitmq"
  engine_type                = "RabbitMQ"
  engine_version             = var.rabbitmq.engine_version
  host_instance_type         = var.rabbitmq.instance_type
  deployment_mode            = "SINGLE_INSTANCE"
  publicly_accessible        = false
  auto_minor_version_upgrade = true
  apply_immediately          = false
  subnet_ids                 = [aws_subnet.private[0].id]
  security_groups            = [aws_security_group.rabbitmq[0].id]
  user {
    username = "nomaos-admin"
    password = random_password.rabbitmq[0].result
  }
  encryption_options {
    use_aws_owned_key = true
  }
  logs {
    general = true
  }
  maintenance_window_start_time {
    day_of_week = "SUNDAY"
    time_of_day = "03:00"
    time_zone   = "UTC"
  }
  lifecycle {
    prevent_destroy = true
  }
  tags = local.tags
}

locals {
  rabbitmq_fqdn = "${var.rabbitmq.subdomain}.${var.domain_name}"
  rabbitmq_proxy_config = var.rabbitmq.enabled ? templatefile("${path.module}/rabbitmq-nginx.conf.tftpl", {
    # Amazon MQ supplies a public-CA HTTPS console hostname, resolving privately.
    broker_host = split(":", split("/", trimprefix(aws_mq_broker.rabbitmq[0].instances[0].console_url, "https://"))[0])[0]
    dns_server  = cidrhost(var.vpc_cidr, 2)
  }) : ""
}

resource "aws_security_group" "rabbitmq_proxy" {
  count       = var.rabbitmq.enabled ? 1 : 0
  name        = "${local.name}-rabbitmq-proxy"
  description = "Management proxy: ALB only; outbound for MQ, image pulls and logging"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "ALB management routing"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    description = "TLS MQ management, image pulls and CloudWatch"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags
}

resource "aws_security_group_rule" "alb_to_rabbitmq_proxy" {
  count                    = var.rabbitmq.enabled ? 1 : 0
  type                     = "egress"
  description              = "ALB to RabbitMQ management proxy"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.rabbitmq_proxy[0].id
}

resource "aws_cloudwatch_log_group" "rabbitmq_proxy" {
  count             = var.rabbitmq.enabled ? 1 : 0
  name              = "/ecs/${local.name}/rabbitmq-proxy"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_ecs_task_definition" "rabbitmq_proxy" {
  count                    = var.rabbitmq.enabled ? 1 : 0
  family                   = "${local.name}-rabbitmq-proxy"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn        = aws_iam_role.ecs_execution.arn
  runtime_platform {
    cpu_architecture        = var.ecs_cpu_architecture
    operating_system_family = "LINUX"
  }
  container_definitions = jsonencode([{
    name      = "rabbitmq-proxy"
    image     = var.rabbitmq.proxy_image
    essential = true
    # Config contains no credentials. Preserve RabbitMQ Authorization headers;
    # each operator logs in using their own broker credentials.
    entryPoint   = ["/bin/sh", "-ec"]
    command      = ["printf '%s' '${base64encode(local.rabbitmq_proxy_config)}' | base64 -d > /etc/nginx/nginx.conf; exec nginx -g 'daemon off;'"]
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.rabbitmq_proxy[0].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
  tags = local.tags
}

resource "aws_lb_target_group" "rabbitmq_proxy" {
  count       = var.rabbitmq.enabled ? 1 : 0
  name        = "${local.name}-rabbitmq"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id
  health_check {
    path    = "/__proxy_health"
    matcher = "200"
  }
  tags = local.tags
}

resource "aws_lb_listener_rule" "rabbitmq_allow" {
  count        = var.rabbitmq.enabled && length(var.rabbitmq.allowed_cidrs) > 0 ? 1 : 0
  listener_arn = aws_lb_listener.https.arn
  priority     = 209
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rabbitmq_proxy[0].arn
  }
  condition {
    host_header { values = [local.rabbitmq_fqdn] }
  }
  condition {
    source_ip { values = var.rabbitmq.allowed_cidrs }
  }
  tags = local.tags
}

resource "aws_lb_listener_rule" "rabbitmq_deny" {
  count        = var.rabbitmq.enabled ? 1 : 0
  listener_arn = aws_lb_listener.https.arn
  priority     = 210
  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
  condition {
    host_header { values = [local.rabbitmq_fqdn] }
  }
  tags = local.tags
}

resource "aws_ecs_service" "rabbitmq_proxy" {
  count           = var.rabbitmq.enabled && length(var.rabbitmq.allowed_cidrs) > 0 ? 1 : 0
  name            = "rabbitmq-proxy"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.rabbitmq_proxy[0].arn
  desired_count   = 1
  launch_type     = "FARGATE"
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  network_configuration {
    subnets          = [aws_subnet.private[0].id]
    security_groups  = [aws_security_group.rabbitmq_proxy[0].id]
    assign_public_ip = false
  }
  # A target group must be attached to a listener before ECS can use it.
  # With no allowlisted IPs there is intentionally no service yet.
  load_balancer {
    target_group_arn = aws_lb_target_group.rabbitmq_proxy[0].arn
    container_name  = "rabbitmq-proxy"
    container_port  = 8080
  }
  depends_on = [aws_lb_listener_rule.rabbitmq_allow]
  tags       = local.tags
}

resource "aws_route53_record" "rabbitmq" {
  count   = var.rabbitmq.enabled ? 1 : 0
  zone_id = local.zone_id
  name    = local.rabbitmq_fqdn
  type    = "A"
  lifecycle {
    precondition {
      condition = (
        !contains([for svc in var.services : svc.subdomain], var.rabbitmq.subdomain) &&
        (!var.enable_vault || var.vault_subdomain != var.rabbitmq.subdomain) &&
        !contains(keys(var.extra_alias_records), var.rabbitmq.subdomain)
      )
      error_message = "RabbitMQ must have a dedicated hostname; sharing another service's ALB route could bypass its management allowlist."
    }
  }
  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
