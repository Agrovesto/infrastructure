output "zone_id" {
  value = local.zone_id
}
output "name_servers" {
  value = local.name_servers
}
output "certificate_arn" {
  value = aws_acm_certificate_validation.this.certificate_arn
}
