output "app_ids" {
  value = { for k, v in aws_amplify_app.this : k => v.id }
}

output "default_domains" {
  value = { for k, v in aws_amplify_app.this : k => v.default_domain }
}

output "branch_urls" {
  value = {
    for k, v in aws_amplify_branch.this :
    k => "https://${v.branch_name}.${aws_amplify_app.this[k].default_domain}"
  }
}

output "custom_domains" {
  value = {
    for k, v in var.apps :
    k => "${v.subdomain}.${var.domain_name}"
  }
}
