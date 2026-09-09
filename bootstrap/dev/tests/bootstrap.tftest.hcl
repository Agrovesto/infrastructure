mock_provider "aws" {
  source          = "../../tests/mocks"
  override_during = plan
}
variables {
  account_id = "111111111111"
}
run "oidc_and_state_isolation" {
  command = plan
  assert {
    condition     = module.account.trust_policy.Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com" && module.account.trust_policy.Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:Agrovesto/infrastructure:environment:dev:ref:refs/heads/dev:event_name:push:workflow_ref:Agrovesto/infrastructure/.github/workflows/infrastructure.yml@refs/heads/dev"
    error_message = "OIDC must bind to this repository, environment, branch, push event and exact workflow."
  }
  assert {
    condition     = strcontains(module.account.environment_backend_hcl, "dev/terraform.tfstate") && strcontains(module.account.bootstrap_backend_hcl, "dev/bootstrap.tfstate") && strcontains(module.account.environment_backend_hcl, "use_lockfile") && strcontains(module.account.environment_backend_hcl, "111111111111")
    error_message = "Bootstrap/application state must be separate, locked and account-constrained."
  }
  assert {
    condition     = module.account.workload_boundary.Statement[1].Effect == "Deny" && module.account.workload_boundary.Statement[1].Sid == "NoTerraformState" && module.account.iam_management_policy.Statement[1].Condition.StringEquals["iam:PermissionsBoundary"] == module.account.permissions_boundary_arn
    error_message = "CI must create only bounded runtime roles, with no access to Terraform state."
  }
}
