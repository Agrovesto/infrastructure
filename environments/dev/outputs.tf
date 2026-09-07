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
output "instance_id" {
  value = module.host.instance_id
}
output "database_volume_id" {
  value = module.host.database_volume_id
}
output "backup_bucket" {
  value = module.host.backup_bucket
}
output "backup_vault" {
  value = module.host.backup_vault
}
output "amplify_apps" {
  value = module.frontends.apps
}
output "amplify_domain_verification" {
  value = module.frontends.domain_verification
}
output "configuration_association_id" {
  value = module.host.configuration_association_id
}
