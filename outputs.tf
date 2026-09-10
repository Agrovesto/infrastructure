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
  description = "Delegate the domain to these NS records at the registrar"
  value       = var.create_hosted_zone ? aws_route53_zone.this[0].name_servers : []
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

output "mssql_fqdn" {
  value = local.mssql_fqdn
}

output "scheduler" {
  value = {
    start = aws_scheduler_schedule.start.arn
    stop  = aws_scheduler_schedule.stop.arn
  }
}
