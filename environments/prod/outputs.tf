output "environment" {
  value = local.environment
}
output "account_id" {
  value = var.account_id
}
output "zone_id" {
  value = module.dns.zone_id
}
output "name_servers" {
  value = module.dns.name_servers
}
output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}
output "database_secret_arns" {
  value = module.sql_secrets.secret_arns
}
output "alerts_topic_arn" {
  value = module.foundation.alerts_topic_arn
}
output "kms_key_arn" {
  value = module.foundation.kms_key_arn
}
output "service_urls" {
  value = { for k, s in var.services : k => s.hostname == "" ? "https://${var.zone_name}" : "https://${s.hostname}.${var.zone_name}" }
}
output "ecs_cluster_name" {
  value = module.services.cluster_name
}
output "sql_admin_run_task_input" {
  value = module.services.admin_run_task_input
}
output "rds_address" {
  value = module.database.address
}
output "rds_identifier" {
  value = module.database.identifier
}
output "rds_engine_version" {
  value = module.database.engine_version
}
output "rds_master_secret_arn" {
  value = module.database.master_secret_arn
}
output "native_backup_bucket" {
  value = module.native_backups.id
}
