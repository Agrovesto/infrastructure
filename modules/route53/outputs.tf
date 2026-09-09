output "zone_id" {
  value = local.zone_id
}

output "name_servers" {
  value = var.create_zone ? aws_route53_zone.this[0].name_servers : []
}

output "fqdns" {
  value = concat(
    [for k, r in aws_route53_record.a : r.fqdn],
    [for k, r in aws_route53_record.cname : r.fqdn],
    [for k, r in aws_route53_record.alias : r.fqdn],
  )
}
