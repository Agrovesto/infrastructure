resource "aws_amplify_app" "this" {
  for_each                    = var.frontends
  name                        = "${var.name}-${each.key}"
  platform                    = "WEB"
  enable_auto_branch_creation = false
  enable_branch_auto_deletion = true
  enable_branch_auto_build    = false
  environment_variables       = each.value.environment_variables
  custom_headers              = <<-HEADERS
    customHeaders:
      - pattern: '**'
        headers:
          - key: Strict-Transport-Security
            value: max-age=31536000
          - key: X-Content-Type-Options
            value: nosniff
          - key: Referrer-Policy
            value: strict-origin-when-cross-origin
  HEADERS
  dynamic "custom_rule" {
    for_each = each.value.spa ? [true] : []
    content {
      source = "</^[^.]+$|\\.(?!(css|gif|ico|jpg|js|png|txt|svg|woff|woff2|ttf|map|json|webp)$)([^.]+$)/>"
      status = "200"
      target = "/index.html"
    }
  }
}
resource "aws_amplify_branch" "this" {
  for_each          = var.frontends
  app_id            = aws_amplify_app.this[each.key].id
  branch_name       = each.value.branch_name
  stage             = "DEVELOPMENT"
  enable_auto_build = false
}
resource "aws_amplify_domain_association" "this" {
  for_each    = { for k, v in var.frontends : k => v if v.domain_prefix != null }
  app_id      = aws_amplify_app.this[each.key].id
  domain_name = each.value.domain_prefix == "" ? var.zone_name : "${each.value.domain_prefix}.${var.zone_name}"
  # DNS records below depend on the returned targets. Waiting here would
  # deadlock creation when the records do not exist yet.
  wait_for_verification = false
  certificate_settings {
    type = "AMPLIFY_MANAGED"
  }
  sub_domain {
    branch_name = aws_amplify_branch.this[each.key].branch_name
    prefix      = ""
  }
}

locals {
  domain_apps = { for k, v in var.frontends : k => v if v.domain_prefix != null }
  certificate_records = { for k, domain in aws_amplify_domain_association.this : k => regexall("\\S+", coalesce(
    domain.certificate_verification_dns_record,
    try(one(domain.certificate_settings).certificate_verification_dns_record, null)
  )) }
}
resource "aws_route53_record" "certificate" {
  for_each        = local.domain_apps
  zone_id         = var.zone_id
  name            = local.certificate_records[each.key][0]
  type            = "CNAME"
  ttl             = 60
  records         = [local.certificate_records[each.key][2]]
  allow_overwrite = false
}
resource "aws_route53_record" "frontend" {
  #checkov:skip=CKV2_AWS_23:The alias targets the CloudFront distribution managed by Amplify, not a separate aws_cloudfront_distribution resource; verify AVAILABLE and HTTPS before traffic.
  for_each        = local.domain_apps
  zone_id         = var.zone_id
  name            = aws_amplify_domain_association.this[each.key].domain_name
  type            = "A"
  allow_overwrite = false
  alias {
    # Amplify returns " CNAME <CloudFront target>" for this subdomain.
    name                   = regexall("\\S+", one(aws_amplify_domain_association.this[each.key].sub_domain).dns_record)[1]
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}
