output "vpc_id" {
  value = module.vpc.vpc_id
}

output "ec2_instance_id" {
  value = module.ec2.instance_id
}

output "ec2_public_ip" {
  value = module.ec2.public_ip
}

output "mssql_backup_bucket" {
  value = module.backup.bucket_id
}

output "route53_name_servers" {
  description = "Delegate the domain to these NS records at the registrar"
  value       = module.dns.name_servers
}

output "frontend_custom_domains" {
  value = module.amplify.custom_domains
}

output "frontend_default_urls" {
  value = module.amplify.branch_urls
}

output "backend_domains" {
  value = module.ec2.api_fqdns
}

output "vault_url" {
  value = "http://${module.ec2.vault_fqdn}"
}

output "scheduler" {
  value = {
    start = module.scheduler.start_schedule_arn
    stop  = module.scheduler.stop_schedule_arn
  }
}
