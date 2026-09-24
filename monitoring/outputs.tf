output "grafana_url" {
  description = "Grafana through the prod ALB (restricted by var.grafana_allowed_cidrs)"
  value       = "https://${local.grafana_host}"
}

output "grafana_admin_user" {
  value = var.grafana_admin_user
}

output "grafana_admin_password_parameter" {
  description = "SSM SecureString holding the generated break-glass admin password"
  value       = aws_ssm_parameter.grafana_admin_password.name
}

output "grafana_authentication" {
  description = "Configured Grafana login methods and the GitHub OAuth callback"
  value = {
    github_enabled        = local.grafana_github_sso_enabled
    github_callback_url   = "https://${local.grafana_host}/login/github"
    allowed_organizations = var.grafana_github_organizations
    github_default_role   = "Viewer"
    local_admin_enabled   = true
    local_admin_user      = var.grafana_admin_user
    local_password_ssm    = aws_ssm_parameter.grafana_admin_password.name
  }
}

output "internal_endpoints" {
  description = "In-VPC endpoints for services that push telemetry"
  value = {
    otlp_grpc        = "alloy.${local.dns_name}:4317"
    otlp_http        = "${local.endpoints.alloy}:4318"
    loki_push        = "${local.endpoints.alloy}:3100"
    loki_query       = "${local.endpoints.loki}"
    prometheus_query = "${local.endpoints.prometheus}"
    tempo_query      = "${local.endpoints.tempo}"
    alertmanager     = "${local.endpoints.alertmanager}"
    pushgateway      = "${local.endpoints.pushgateway}"
  }
}

output "dashboard_uids" {
  value = {
    platform = "agrovesto-platform"
    services = "agrovesto-services"
    cost     = "agrovesto-cost"
  }
}

output "config_parameter_prefix" {
  description = "SSM prefix holding every rendered config file"
  value       = local.param
}

output "efs_file_system_id" {
  value = aws_efs_file_system.monitoring.id
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.monitoring.name
}

output "security_group_ids" {
  value = {
    internal = aws_security_group.internal.id
    grafana  = aws_security_group.grafana.id
    efs      = aws_security_group.efs.id
  }
}

output "cur_bucket" {
  description = "Cost and usage report bucket (empty when cost monitoring is off)"
  value       = var.enable_cost_monitoring ? aws_s3_bucket.cur[0].bucket : ""
}

output "budget_task_name" {
  description = "Task definition family the daily budget job runs from"
  value       = var.enable_cost_monitoring ? aws_ecs_task_definition.budget[0].family : ""
}
