output "instance_id" {
  value = aws_instance.this.id
}
output "database_volume_id" {
  value = aws_ebs_volume.database.id
}
output "backup_bucket" {
  value = module.backups.id
}
output "backup_vault" {
  value = aws_backup_vault.this.name
}
output "admin_secret_arn" {
  value = aws_secretsmanager_secret.admin.arn
}
output "configuration_association_id" {
  value = aws_ssm_association.configure.association_id
}
output "rendered_compose" {
  description = "Contains only configuration and secret file paths, never passwords. Useful for offline tests."
  value       = local.compose
}
output "security" {
  value = {
    public_ip          = aws_instance.this.associate_public_ip_address
    imds_tokens        = aws_instance.this.metadata_options[0].http_tokens
    imds_hops          = aws_instance.this.metadata_options[0].http_put_response_hop_limit
    root_encrypted     = aws_instance.this.root_block_device[0].encrypted
    database_encrypted = aws_ebs_volume.database.encrypted
    root_size          = aws_instance.this.root_block_device[0].volume_size
    database_size      = aws_ebs_volume.database.size
    backup_resources   = aws_backup_selection.this.resources
    backup_schedule    = one(aws_backup_plan.this.rule).schedule
  }
}
