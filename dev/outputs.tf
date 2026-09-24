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
  description = "Vault is local to the host; use SSH/SSM port forwarding to reach this loopback endpoint"
  value       = "http://127.0.0.1:${var.vault.host_port}"
}

output "ecr_repository_urls" {
  description = "Push/pull URLs for the dev API image repos (agrovesto-dev-<svc>). docker-compose pulls from these after the user_data ECR login."
  value       = { for k, r in aws_ecr_repository.apis : k => r.repository_url }
}

output "mssql_fqdn" {
  value = local.mssql_fqdn
}

# =============================================================================
# Redis
# =============================================================================

output "redis_endpoint" {
  description = "What the APIs on this host connect to. Reachable only from inside the compose network; the published host port is loopback-only."
  value       = var.redis.enabled ? "redis:6379" : ""
}

output "redis_access" {
  description = "How to reach Redis from a laptop. There is no public endpoint and no security group ingress for it, so the tunnel is the only way in."
  value = var.redis.enabled ? {
    ssh_tunnel = "ssh -N -L ${var.redis.host_port}:127.0.0.1:${var.redis.host_port} ubuntu@${local.ec2_public_ip}"
    redis_cli  = "redis-cli -h 127.0.0.1 -p ${var.redis.host_port}${var.redis.password != "" ? " -a \"$REDIS_PASSWORD\"  # from /opt/agrovesto/compose/.env on the host, or SSM /${local.name}/redis_password" : "  # no AUTH configured"}"
    maxmemory  = "${var.redis.maxmemory_mb}mb, evicting ${var.redis.maxmemory_policy}"
    persisted  = var.redis.persistence
  } : null
}

# =============================================================================
# SonarQube
# =============================================================================

output "sonarqube_url" {
  description = "Set this as the SONAR_HOST_URL repository secret. Empty when sonarqube.enabled = false or expose_via_nginx = false, in which case there is no public name and CI cannot reach the server."
  value       = local.sonarqube_nginx.enabled ? "${local.sonar_public_scheme}://${local.sonar_fqdn}" : ""
}

output "sonarqube_fqdn" {
  description = "The hostname to point at the dev Elastic IP in the prod account's zone (prod/terraform.auto.tfvars -> extra_a_records), since dev manages no DNS of its own."
  value       = local.sonar_fqdn
}

output "sonarqube_access" {
  description = "How to reach SonarQube, and what to expect on first boot"
  value = var.sonarqube.enabled ? {
    # With allowed_cidrs empty the nginx vhost denies everything but 127.0.0.1,
    # so the tunnel is the way in — and the reason CI cannot scan yet.
    ssh_tunnel = local.sonarqube_nginx.enabled && length(var.sonarqube.allowed_cidrs) == 0 ? "ssh -N -L ${var.sonarqube.host_port}:127.0.0.1:${var.sonarqube.host_port} ubuntu@${local.ec2_public_ip}" : "(allow list is not empty; use the URL directly)"
    local_url  = "http://localhost:${var.sonarqube.host_port}  (first login is admin/admin and SonarQube forces a password change)"
    dns_record = "add \"${var.sonarqube.subdomain}\" = \"${local.ec2_public_ip}\" to extra_a_records in prod/terraform.auto.tfvars"
    database   = "${var.sonarqube.database_name} on the on-host SQL Server, collation ${var.sonarqube.database_collation}, login ${var.sonarqube.database_username} (password in SSM /${local.name}/sonarqube_db_password)"
    first_boot = "SonarQube starts before init-dbs.sql has run, fails to reach its database and is restarted by compose until the schema exists. Expect a few restarts and 2-5 minutes before the UI answers on a 1 GB heap."
    scanner_ip = length(var.sonarqube.allowed_cidrs) == 0 ? "WARNING: sonarqube.allowed_cidrs is empty, so the nginx vhost answers 127.0.0.1 only and GitHub Actions runners are denied. Add your runner or NAT egress CIDR before pointing CI at this server." : "allowed: ${join(", ", var.sonarqube.allowed_cidrs)}"
  } : null
}

output "sonarqube_authentication" {
  description = "Configured SonarQube login methods and GitHub App callback"
  value = var.sonarqube.enabled ? {
    github_enabled        = local.sonarqube_github_sso_enabled
    github_callback_url   = "https://${local.sonar_fqdn}"
    allowed_organizations = var.sonarqube_github_organizations
    local_admin_enabled   = true
    initial_local_login   = "admin / admin (first boot only; SonarQube forces a password change)"
    ci_authentication     = "SONAR_TOKEN (GitHub SSO is for people, not scanners)"
  } : null
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
  description = "Empty when logging.enabled = false or expose_via_nginx = false. Limited to logging.allowed_cidrs; GitHub SSO automatically enables HTTPS through Caddy."
  value       = var.logging.enabled && var.logging.expose_via_nginx ? "${local.grafana_public_scheme}://${local.grafana_fqdn}" : ""
}

output "grafana_authentication" {
  description = "Configured dev Grafana login methods and GitHub OAuth callback"
  value = var.logging.enabled ? {
    github_enabled        = local.grafana_github_sso_enabled
    github_callback_url   = "https://${local.grafana_fqdn}/login/github"
    allowed_organizations = var.grafana_github_organizations
    github_default_role   = "Viewer"
    local_admin_enabled   = true
    local_admin_user      = var.logging.grafana_admin_user
    local_password_ssm    = var.logging.enabled ? aws_ssm_parameter.grafana_admin_password[0].name : null
  } : null
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

output "rekognition" {
  description = "Values the apps need to call Rekognition"
  value = {
    collection_ids            = [for c in aws_rekognition_collection.this : c.collection_id]
    media_bucket              = aws_s3_bucket.rekognition.bucket
    video_sns_topic_arn       = aws_sns_topic.rekognition_video.arn
    video_role_arn            = aws_iam_role.rekognition_video.arn
    video_queue_url           = aws_sqs_queue.rekognition_video.id
    liveness_identity_pool_id = one(aws_cognito_identity_pool.liveness[*].id)
  }
}
