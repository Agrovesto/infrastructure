# =============================================================================
# Route 53 — hosted zone + records
#
# A records  : every backend / vault / mssql hostname -> EC2 Elastic IP (nginx)
# CNAMEs     : every Amplify frontend subdomain -> Amplify default domain
#
# NOTE: DNS for the root domain is owned by the PROD account, which manages
# this environment's records as dev.<domain> hostnames (see
# prod/terraform.auto.tfvars). This whole file is therefore gated behind
# var.manage_dns, which dev/terraform.auto.tfvars sets to false: the stack
# creates no zone and no records here.
# =============================================================================

resource "aws_route53_zone" "this" {
  count = var.manage_dns && var.create_hosted_zone ? 1 : 0

  name = var.domain_name

  tags = merge(local.tags, { Name = var.domain_name })
}

resource "aws_route53_record" "a" {
  #checkov:skip=CKV2_AWS_23: A records point at the EC2 host's Elastic IP via local.ec2_public_ip (checkov cannot trace the IP string to the instance)
  for_each = var.manage_dns ? local.a_records : {}

  zone_id = local.zone_id
  name    = each.key == "@" ? var.domain_name : "${each.key}.${var.domain_name}"
  type    = "A"
  ttl     = var.dns_ttl
  records = [each.value]
}

resource "aws_route53_record" "cname" {
  for_each = var.manage_dns ? local.cname_records : {}

  zone_id = local.zone_id
  name    = "${each.key}.${var.domain_name}"
  type    = "CNAME"
  ttl     = var.dns_ttl
  records = [each.value]
}

resource "aws_route53_record" "alias" {
  #checkov:skip=CKV2_AWS_23: user-supplied alias targets (var.extra_alias_records); attachment is the caller's responsibility
  for_each = var.manage_dns ? var.extra_alias_records : {}

  zone_id = local.zone_id
  name    = each.key == "@" ? var.domain_name : "${each.key}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = each.value.name
    zone_id                = each.value.zone_id
    evaluate_target_health = each.value.evaluate_target_health
  }
}
