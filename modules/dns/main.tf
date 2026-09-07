resource "aws_route53_zone" "this" {
  #checkov:skip=CKV2_AWS_38:DNSSEC requires a coordinated registrar DS cutover; explicitly deferred in docs/dns.md.
  #checkov:skip=CKV2_AWS_39:Public query logging requires separate us-east-1 resources and retention decisions; explicitly deferred in docs/dns.md.

  count         = var.existing_zone_id == null ? 1 : 0
  name          = var.zone_name
  comment       = "Terraform managed public zone; delegate at the registrar or parent zone"
  force_destroy = false
  lifecycle {
    prevent_destroy = true
  }
}
data "aws_route53_zone" "existing" {
  count   = var.existing_zone_id == null ? 0 : 1
  zone_id = var.existing_zone_id
  lifecycle {
    postcondition {
      condition     = trimsuffix(self.name, ".") == var.zone_name && !self.private_zone
      error_message = "The supplied hosted zone must be public and match zone_name."
    }
  }
}
locals {
  zone_id      = var.existing_zone_id == null ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.existing[0].zone_id
  name_servers = var.existing_zone_id == null ? aws_route53_zone.this[0].name_servers : data.aws_route53_zone.existing[0].name_servers
}
resource "aws_route53_record" "records" {
  for_each        = var.records
  zone_id         = local.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = each.value.ttl
  records         = each.value.records
  allow_overwrite = false
}
resource "aws_route53_record" "aliases" {
  for_each        = var.aliases
  zone_id         = local.zone_id
  name            = each.value.name
  type            = each.value.type
  allow_overwrite = false
  alias {
    name                   = each.value.target_name
    zone_id                = each.value.target_zone_id
    evaluate_target_health = each.value.evaluate_target_health
  }
}
resource "aws_acm_certificate" "this" {
  domain_name               = var.zone_name
  subject_alternative_names = ["*.${var.zone_name}"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}
# ACM uses the same CNAME for an apex name and its wildcard. Manage it only once.
resource "aws_route53_record" "certificate" {
  zone_id         = local.zone_id
  name            = one([for d in aws_acm_certificate.this.domain_validation_options : d.resource_record_name if d.domain_name == var.zone_name])
  type            = "CNAME"
  ttl             = 60
  records         = [one([for d in aws_acm_certificate.this.domain_validation_options : d.resource_record_value if d.domain_name == var.zone_name])]
  allow_overwrite = false
}
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [aws_route53_record.certificate.fqdn]
  timeouts {
    create = "45m"
  }
}
