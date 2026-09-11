# =============================================================================
# Route 53 — ALL public DNS is owned by the PROD account.
#
# This module creates/manages the hosted zone for the root domain and every
# record in it:
#
#   prod services (alias -> ALB):
#     wallet.nomaos.com, onboarding-api.nomaos.com, input.nomaos.com,
#     moneval.nomaos.com, serviceprovider.nomaos.com
#
#   dev records (plain A/CNAME via var.extra_a_records / var.extra_cname_records
#   in terraform.auto.tfvars): dev is served from the dev.<domain> subdomain
#   (wallet.dev.nomaos.com -> dev EC2 Elastic IP, etc.) and creates no zone or
#   records of its own.
#
# Registrar: delegate the root domain's NS records to the
# `route53_name_servers` output of this stack.
# =============================================================================

resource "aws_route53_zone" "this" {
  count = var.create_hosted_zone ? 1 : 0

  name = var.domain_name

  tags = merge(local.tags, { Name = var.domain_name })
}

# Prod service aliases -> ALB.
resource "aws_route53_record" "alias" {
  #checkov:skip=CKV2_AWS_23: alias records point at the ALB via aws_lb.main (checkov cannot trace alias targets)
  for_each = local.alias_records

  zone_id = local.zone_id
  name    = each.key == "@" ? var.domain_name : "${each.key}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = each.value.name
    zone_id                = each.value.zone_id
    evaluate_target_health = each.value.evaluate_target_health
  }
}

# Plain A records (e.g. the dev hosts -> dev EC2 Elastic IP).
resource "aws_route53_record" "a" {
  #checkov:skip=CKV2_AWS_23: user-supplied IPs (e.g. the dev EC2 Elastic IP); wiring is the caller's responsibility
  for_each = var.extra_a_records

  zone_id = local.zone_id
  name    = each.key == "@" ? var.domain_name : "${each.key}.${var.domain_name}"
  type    = "A"
  ttl     = var.dns_ttl
  records = [each.value]
}

# CNAME records (e.g. the dev Amplify frontend subdomains).
resource "aws_route53_record" "cname" {
  for_each = var.extra_cname_records

  zone_id = local.zone_id
  name    = "${each.key}.${var.domain_name}"
  type    = "CNAME"
  ttl     = var.dns_ttl
  records = [each.value]
}
