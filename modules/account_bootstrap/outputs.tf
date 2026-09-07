output "deployment_role_arn" {
  value = aws_iam_role.deploy.arn
}
output "permissions_boundary_arn" {
  value = aws_iam_policy.workload_boundary.arn
}
output "github_oidc_subject" {
  value = local.github_subject
}
output "state_bucket" {
  value = module.state.id
}
output "state_kms_key_arn" {
  value = aws_kms_key.state.arn
}
output "environment_backend_hcl" {
  value = <<-HCL
    bucket              = "${module.state.id}"
    key                 = "${local.state_key}"
    region              = "${var.region}"
    encrypt             = true
    kms_key_id          = "${aws_kms_key.state.arn}"
    use_lockfile        = true
    allowed_account_ids = ["${var.account_id}"]
  HCL
}
output "bootstrap_backend_hcl" {
  value = <<-HCL
    bucket              = "${module.state.id}"
    key                 = "${local.bootstrap_key}"
    region              = "${var.region}"
    encrypt             = true
    kms_key_id          = "${aws_kms_key.state.arn}"
    use_lockfile        = true
    allowed_account_ids = ["${var.account_id}"]
  HCL
}
output "trust_policy" {
  value = jsondecode(aws_iam_role.deploy.assume_role_policy)
}
output "workload_boundary" {
  value = jsondecode(aws_iam_policy.workload_boundary.policy)
}
output "iam_management_policy" {
  value = jsondecode(aws_iam_role_policy.iam.policy)
}
output "zone_id" {
  value = var.bootstrap_zone_name == null ? null : aws_route53_zone.bootstrap[0].zone_id
}
output "zone_name_servers" {
  value = var.bootstrap_zone_name == null ? [] : aws_route53_zone.bootstrap[0].name_servers
}
