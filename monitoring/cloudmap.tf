# Private DNS for the monitoring endpoints (<component>.monitoring.internal).
# ECS registers each task's IP in the matching service, so nothing depends on
# task addresses or on a load balancer for internal traffic.

resource "aws_service_discovery_private_dns_namespace" "monitoring" {
  name = local.dns_name
  vpc  = data.aws_vpc.prod.id

  tags = local.tags
}

locals {
  discovery_services = {
    prometheus   = 9090
    alertmanager = 9093
    loki         = 3100
    tempo        = 3200
    grafana      = 3000
    blackbox     = 9115
    pushgateway  = 9091
    alloy        = 4317
  }
}

resource "aws_service_discovery_service" "monitoring" {
  for_each = local.discovery_services

  name = each.key

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.monitoring.id

    dns_records {
      type = "A"
      ttl  = 10
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = merge(local.tags, { Name = "${local.name}-${each.key}" })
}

resource "aws_ecs_cluster" "monitoring" {
  name = local.name

  # Container Insights is deliberately off: this stack replaces it.
  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "monitoring" {
  #checkov:skip=CKV_AWS_338: 30 days is enough for the monitoring components' own logs, which are also shipped to Loki
  name              = "/ecs/${local.name}"
  retention_in_days = var.log_retention_days

  tags = local.tags
}
