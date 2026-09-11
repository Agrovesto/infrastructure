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
  value = { for k, s in aws_ecs_service.services : k => s.name }
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
  description = "Secrets Manager ARN holding { username, password } for the SQL Server master user"
  value       = aws_secretsmanager_secret.mssql_master.arn
}

output "mssql_databases" {
  value = var.mssql_databases
}

output "mssql_db_init_sql" {
  description = "Runbook SQL (also executed by the db-init task when var.run_db_init = true)"
  value       = local.db_init_sql
}
