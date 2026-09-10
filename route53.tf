# =============================================================================
# Route 53 — hosted zone + records
#
# A records  : every backend / vault / mssql hostname -> EC2 Elastic IP (nginx)
# CNAMEs     : every Amplify frontend subdomain -> Amplify default domain
# =============================================================================

resource "aws_route53_zone" "this" {
  count = var.create_hosted_zone ? 1 : 0

  name = var.domain_name

  tags = merge(local.tags, { Name = var.domain_name })
}

resource "aws_route53_record" "a" {
  for_each = local.a_records

  zone_id = local.zone_id
  name    = each.key == "@" ? var.domain_name : "${each.key}.${var.domain_name}"
  type    = "A"
  ttl     = var.dns_ttl
  records = [each.value]
}

resource "aws_route53_record" "cname" {
  for_each = local.cname_records

  zone_id = local.zone_id
  name    = "${each.key}.${var.domain_name}"
  type    = "CNAME"
  ttl     = var.dns_ttl
  records = [each.value]
}

resource "aws_route53_record" "alias" {
  for_each = var.extra_alias_records

  zone_id = local.zone_id
  name    = each.key == "@" ? var.domain_name : "${each.key}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = each.value.name
    zone_id                = each.value.zone_id
    evaluate_target_health = each.value.evaluate_target_health
  }
}
