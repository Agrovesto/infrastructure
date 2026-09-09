output "instance_id" {
  value = aws_instance.this.id
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "public_ip" {
  value = var.associate_elastic_ip ? aws_eip.this[0].public_ip : aws_instance.this.public_ip
}

output "api_fqdns" {
  value = "${wallet-subdomain}.${var.domain_name}"
}

output "api_fqdns" {
  value = "${onboarding-subdomain}.${var.domain_name}"
}

output "api_fqdns" {
  value = " ${input-subdomain}.${var.domain_name}"
}

output "api_fqdns" {
  value = "${moneval-subdomain}.${var.domain_name}"
}

output "api_fqdns" {
  value = "${serviceprovider-subdomain}.${var.domain_name}"
}

output "vault_fqdn" {
  value = "${var.vault.subdomain}.${var.domain_name}"
}

output "mssql_fqdn" {
  value = "${var.mssql.subdomain}.${var.domain_name}"
}