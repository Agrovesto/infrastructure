output "apps" {
  value = { for k, app in aws_amplify_app.this : k => {
    app_id = app.id, branch = aws_amplify_branch.this[k].branch_name,
    url    = "https://${aws_amplify_branch.this[k].branch_name}.${app.default_domain}"
  } }
}
output "domain_verification" {
  value = { for k, domain in aws_amplify_domain_association.this : k => {
    certificate_verification_dns_record = domain.certificate_verification_dns_record
    sub_domains                         = domain.sub_domain
  } }
}

output "managed_dns_records" {
  value = length(aws_route53_record.certificate) + length(aws_route53_record.frontend)
}
