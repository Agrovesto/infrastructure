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

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  value = aws_subnet.database[*].id
}

# -- ECS / ECR ------------------------------------------------------------------

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_names" {
  value = merge(
    { for k, s in aws_ecs_service.services : k => s.name },
    var.enable_vault ? { vault = aws_ecs_service.vault[0].name } : {}
  )
}

# -- Vault ------------------------------------------------------------------------

output "vault_url" {
  value = var.enable_vault ? "https://${var.vault_subdomain}.${var.domain_name}" : null
}

output "vault_kms_key_id" {
  description = "CMK used for Vault auto-unseal and the Vault EFS volume"
  value       = var.enable_vault ? aws_kms_key.vault.key_id : null
}

output "vault_efs_file_system_id" {
  value = var.enable_vault ? aws_efs_file_system.vault[0].id : null
}

output "ecr_repository_urls" {
  description = "Push service images here, then point var.services.<svc>.image at them"
  value       = { for k, r in aws_ecr_repository.services : k => r.repository_url }
}

# -- ALB / DNS ------------------------------------------------------------------

output "alb_dns_name" {
  description = "Internal hostname of the ALB (Route53 aliases point here)"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  value = aws_lb.main.zone_id
}

output "alb_logs_bucket" {
  value = aws_s3_bucket.alb_logs.id
}

output "service_fqdns" {
  description = "Public URL of every service"
  value       = { for k, fqdn in local.service_fqdns : k => "https://${fqdn}" }
}

output "route53_zone_id" {
  value = local.zone_id
}

output "route53_name_servers" {
  description = "Delegate the domain to these NS records at the registrar"
  value       = var.create_hosted_zone ? aws_route53_zone.this[0].name_servers : []
}

output "agrovesto_zone_id" {
  description = "Zone ID of the imported agrovesto.com zone"
  value       = aws_route53_zone.agrovesto.zone_id
}

output "agrovesto_zone_name_servers" {
  description = "NS servers of the imported agrovesto.com zone (for registrar delegation if ever needed)"
  value       = aws_route53_zone.agrovesto.name_servers
}

# -- RDS ------------------------------------------------------------------------

output "mssql_endpoint" {
  value = aws_db_instance.mssql.endpoint
}

output "mssql_address" {
  value = aws_db_instance.mssql.address
}

output "mssql_port" {
  value = aws_db_instance.mssql.port
}

output "mssql_master_secret_arn" {
  description = "RDS-managed Secrets Manager secret holding { username, password } for the SQL Server master user"
  value       = local.mssql_master_secret_arn
}

output "mssql_databases" {
  value = var.mssql_databases
}

output "mssql_db_init_sql" {
  description = "Runbook SQL (also executed by the db-init task when var.run_db_init = true)"
  value       = local.db_init_sql
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

output "rabbitmq_access" {
  description = "Private ECS-only TLS endpoints and admin secret ARN (no password)."
  value = var.rabbitmq.enabled ? {
    amqps_endpoints   = aws_mq_broker.rabbitmq[0].instances[0].endpoints
    management_url   = aws_mq_broker.rabbitmq[0].instances[0].console_url
    admin_secret_arn = aws_secretsmanager_secret.rabbitmq[0].arn
  } : null
}
