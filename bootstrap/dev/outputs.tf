output "deployment_role_arn" {
  value = module.account.deployment_role_arn
}
output "permissions_boundary_arn" {
  value = module.account.permissions_boundary_arn
}
output "github_oidc_subject" {
  value = module.account.github_oidc_subject
}
output "state_bucket" {
  value = module.account.state_bucket
}
output "state_kms_key_arn" {
  value = module.account.state_kms_key_arn
}
output "environment_backend_hcl" {
  value = module.account.environment_backend_hcl
}
output "bootstrap_backend_hcl" {
  value = module.account.bootstrap_backend_hcl
}

output "zone_id" {
  value = module.account.zone_id
}
output "zone_name_servers" {
  value = module.account.zone_name_servers
}
