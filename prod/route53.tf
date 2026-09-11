# =============================================================================
# Route 53 — hosted zone + one alias A record per service subdomain -> ALB
#
#   wallet.nomaos.com          ┐
#   onboarding-api.nomaos.com  │
#   input.nomaos.com           ├-> ALB (public subnets)
#   moneval.nomaos.com         │
#   serviceprovider.nomaos.com ┘
#
# NOTE: the dev stack also manages a zone for the same root domain in the DEV
# account. Only one zone can be authoritative — delegate the registrar NS
# records to the PROD zone when prod takes over the domain (see
# terraform.auto.tfvars).
# =============================================================================

resource "aws_route53_zone" "this" {
  count = var.create_hosted_zone ? 1 : 0

  name = var.domain_name

  tags = merge(local.tags, { Name = var.domain_name })
}

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
