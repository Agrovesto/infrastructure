# Private Amazon MQ: only application services carrying the dedicated client
# security group may reach AMQP or management. No public proxy or DNS route.
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
  description = "Private RabbitMQ: TLS AMQP and HTTPS from authorized ECS services only"
  vpc_id      = aws_vpc.main.id
  ingress {
    description      = "TLS AMQP from ECS apps"
    from_port        = 5671
    to_port          = 5671
    protocol         = "tcp"
    cidr_blocks      = []
    ipv6_cidr_blocks = []
    security_groups  = [aws_security_group.rabbitmq_clients[0].id]
  }
  ingress {
    description      = "Management HTTPS from authorized ECS services"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = []
    ipv6_cidr_blocks = []
    security_groups  = [aws_security_group.rabbitmq_clients[0].id]
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

# Membership is granted only to this cluster's application ECS services below.
# Do not reuse this SG on EC2, other clusters, or externally reachable proxies.
# Network ACLs/SGs identify ENIs, not ECS cluster identity; IAM must govern who
# can attach this group. The existing ECS SG supplies application egress.
resource "aws_security_group" "rabbitmq_clients" {
  count       = var.rabbitmq.enabled ? 1 : 0
  name        = "${local.name}-rabbitmq-clients"
  description = "RabbitMQ client identity for this cluster's application services"
  vpc_id      = aws_vpc.main.id
  tags        = local.tags
}
