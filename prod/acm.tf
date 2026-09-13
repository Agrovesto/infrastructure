# =============================================================================
# ACM — wildcard certificate for *.<domain> (+ the apex), DNS-validated
# through the Route53 zone. Covers every service subdomain the ALB serves.
# =============================================================================

resource "aws_acm_certificate" "wildcard" {
  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.tags, { Name = "*.${var.domain_name}" })
}

locals {
  acm_validation_domains = toset(concat(
    [aws_acm_certificate.wildcard.domain_name],
    aws_acm_certificate.wildcard.subject_alternative_names
  ))
  acm_dvo = { for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => dvo }
}

resource "aws_route53_record" "acm_validation" {
  for_each = local.acm_validation_domains

  zone_id         = local.zone_id
  name            = local.acm_dvo[each.key].resource_record_name
  type            = local.acm_dvo[each.key].resource_record_type
  ttl             = 60
  records         = [local.acm_dvo[each.key].resource_record_value]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}
