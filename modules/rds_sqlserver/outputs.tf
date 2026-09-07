output "address" {
  value = aws_db_instance.this.address
}
output "identifier" {
  value = aws_db_instance.this.identifier
}
output "security_group_id" {
  value = aws_security_group.this.id
}
output "master_secret_arn" {
  value = aws_db_instance.this.master_user_secret[0].secret_arn
}
output "engine_version" {
  value = aws_db_instance.this.engine_version_actual
}
output "security" {
  value = {
    engine              = aws_db_instance.this.engine
    license_model       = aws_db_instance.this.license_model
    encrypted           = aws_db_instance.this.storage_encrypted
    public              = aws_db_instance.this.publicly_accessible
    multi_az            = aws_db_instance.this.multi_az
    port                = aws_db_instance.this.port
    managed_password    = aws_db_instance.this.manage_master_user_password
    backup_days         = aws_db_instance.this.backup_retention_period
    deletion_protection = aws_db_instance.this.deletion_protection
    final_snapshot      = !aws_db_instance.this.skip_final_snapshot
    tls_required        = one(aws_db_parameter_group.this.parameter).value
  }
}
