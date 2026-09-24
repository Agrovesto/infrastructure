# =============================================================================
# Outputs
# =============================================================================

output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr_block" {
  value = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "ec2_security_group_id" {
  value = aws_security_group.ec2.id
}

output "ec2_instance_id" {
  value = aws_instance.app.id
}

output "ec2_private_ip" {
  value = aws_instance.app.private_ip
}

output "ec2_public_ip" {
  value = local.ec2_public_ip
}

output "ec2_instance_profile_name" {
  value = aws_iam_instance_profile.ec2.name
}

output "scheduler_role_arn" {
  value = aws_iam_role.scheduler.arn
}

output "mssql_backup_bucket" {
  value = aws_s3_bucket.backup.id
}

output "mssql_backup_bucket_arn" {
  value = aws_s3_bucket.backup.arn
}

output "route53_zone_id" {
  value = local.zone_id
}

output "route53_name_servers" {
  description = "Empty when var.manage_dns = false — the prod account owns the zone and delegation"
  value       = var.manage_dns && var.create_hosted_zone ? aws_route53_zone.this[0].name_servers : []
}

output "dns_fqdns" {
  value = concat(
    [for k, r in aws_route53_record.a : r.fqdn],
    [for k, r in aws_route53_record.cname : r.fqdn],
    [for k, r in aws_route53_record.alias : r.fqdn],
  )
}

output "frontend_app_ids" {
  value = { for k, v in aws_amplify_app.this : k => v.id }
}

output "frontend_default_domains" {
  value = { for k, v in aws_amplify_app.this : k => v.default_domain }
}

output "frontend_default_urls" {
  value = {
    for k, v in aws_amplify_branch.this :
    k => "https://${v.branch_name}.${aws_amplify_app.this[k].default_domain}"
  }
}

output "frontend_custom_domains" {
  value = { for k, v in var.amplify_apps : k => "${v.subdomain}.${var.domain_name}" }
}

output "backend_domains" {
  value = local.api_fqdns
}

output "vault_url" {
  value = "http://${local.vault_fqdn}"
}

output "ecr_repository_urls" {
  description = "Push/pull URLs for the dev API image repos (agrovesto-dev-<svc>). docker-compose pulls from these after the user_data ECR login."
  value       = { for k, r in aws_ecr_repository.apis : k => r.repository_url }
}

output "mssql_fqdn" {
  value = local.mssql_fqdn
}

output "scheduler" {
  value = {
    start = aws_scheduler_schedule.start.arn
    stop  = aws_scheduler_schedule.stop.arn
  }
}

# =============================================================================
# Logging & metrics on the host
# =============================================================================

output "grafana_url" {
  description = "Empty when logging.enabled = false or expose_via_nginx = false. Served by nginx on the box's port 80 and limited to logging.allowed_cidrs - with the default empty allow list the vhost answers 127.0.0.1 only, so use the tunnel below."
  value       = var.logging.enabled && var.logging.expose_via_nginx ? "http://${local.grafana_fqdn}" : ""
}

output "logging_access" {
  description = "How to reach the UI and the raw APIs from a laptop"
  value = var.logging.enabled ? {
    ssh_tunnel = "ssh -N -L ${var.logging.grafana_port}:127.0.0.1:${var.logging.grafana_port} -L ${var.logging.loki_port}:127.0.0.1:${var.logging.loki_port} -L ${var.logging.prometheus_port}:127.0.0.1:${var.logging.prometheus_port} ubuntu@${local.ec2_public_ip}"
    grafana    = "http://localhost:${var.logging.grafana_port}  (user ${var.logging.grafana_admin_user}; password is var.logging.grafana_admin_password)"
    loki_query = "http://localhost:${var.logging.loki_port}/loki/api/v1/query_range?query=%7Bjob%3D%22docker%22%7D&limit=20"
    alloy_ui   = "http://localhost:${var.logging.alloy_port}/  (component graph - the way to see whether a collector is actually reading)"
  } : null
}

output "logging_summary" {
  description = "What the on-host logging stack keeps and where"
  value = var.logging.enabled ? {
    data_dir             = local.logging_root
    volume_gb            = var.logging.volume_size_gb
    loki_retention       = "${var.logging.loki_retention_days}d (journald + nginx: ${var.logging.system_retention_days}d)"
    prometheus_retention = "${var.logging.prometheus_retention}, ${var.logging.prometheus_retention_size} cap"
    parsed_as_json       = local.logging_json_services
    grafana_cidrs        = local.logging_grafana.cidrs
    self_scrape_dropped  = local.logging_own_services
  } : null
}

output "sns_alerts_topic_arn" {
  description = "CloudWatch alarms publish here"
  value       = aws_sns_topic.alerts.arn
}

output "sns_app_topic_arns" {
  description = "Application topics, by name"
  value       = { for k, t in aws_sns_topic.app : k => t.arn }
}
