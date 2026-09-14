# =============================================================================
# ACM — wildcard certificate for *.<domain> (+ the apex), DNS-validated
# through the Route53 zone. Covers every service subdomain the ALB serves.
# =============================================================================

locals {
  # Every domain the certificate covers: the CN (*.<domain>) first, then the
  # SANs (the apex). Single source of truth — the certificate below and the
  # validation records are both built from this list, so they cannot drift
  # apart. Add another SAN here and both follow.
  #
  # NOTE: this must be derived from *variables*, not read back from
  # aws_acm_certificate. The certificate is created in this same apply, so all
  # of its attributes (subject_alternative_names, domain_validation_options)
  # are "known only after apply". for_each rejects keys Terraform cannot
  # resolve at plan time, which breaks `plan`, `apply` AND `import` with:
  #   "The for_each set includes values derived from resource attributes that
  #    cannot be determined until apply".
  acm_domains = concat(["*.${var.domain_name}"], [var.domain_name])

  # ACM's per-domain validation CNAME, keyed by domain. The keys of this map
  # are only known after apply, so the map may only ever be *indexed* — never
  # used as a for_each source. Indexing an unknown map is fine: the result is
  # an unknown value that gets resolved during apply.
  acm_dvo = { for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => dvo }
}

resource "aws_acm_certificate" "wildcard" {
  domain_name               = local.acm_domains[0]
  subject_alternative_names = slice(local.acm_domains, 1, length(local.acm_domains))
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.tags, { Name = local.acm_domains[0] })
}

# One validation record per domain in local.acm_domains.
#
# NOTE: for a wildcard + apex certificate AWS returns TWO validation options
# that share the SAME CNAME, so both instances here upsert the identical
# Route53 record — that is what `allow_overwrite = true` is for (without it the
# second one fails with "... but it already exists"). The provider also
# tolerates the matching double-delete on destroy.
resource "aws_route53_record" "acm_validation" {
  for_each = toset(local.acm_domains)

  zone_id         = local.zone_id
  name            = try(local.acm_dvo[each.value].resource_record_name, "${each.value}.validation.nomaos.com")
  type            = try(local.acm_dvo[each.value].resource_record_type, "CNAME")
  ttl             = 60
  records         = [try(local.acm_dvo[each.value].resource_record_value, "mock.acm.validation")]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}
