# Bootstrap import for the DEV account (353833416626).
#   AWS_PROFILE=agrovesto-dev terraform plan -state=dev.tfstate -var-file=dev.tfvars
account_id       = "353833416626"
environment      = "dev"
deploy_role_name = "nomaos-dev-github-terraform" # the role in the AWS_ROLE_ARN_DEV secret

# The trust policy gets REWRITTEN to exactly these patterns on apply. dev.yml
# deploys on push to `dev` and plans on PRs into `dev`, so `dev` must stay in
# the list or dev CI loses AWS access. Compare with the role's current trust
# policy first:
#   aws iam get-role --role-name nomaos-dev-github-terraform --query Role.AssumeRolePolicyDocument
# Restrict the imported role to this repository before the next apply.
github_sub_patterns = [
  "repo:Agrovesto@101108012/infrastructure@1360104538:ref:refs/heads/main",
  "repo:Agrovesto@101108012/infrastructure@1360104538:ref:refs/heads/dev",
  "repo:Agrovesto@101108012/infrastructure@1360104538:pull_request",
  # Apply jobs run in the "dev" GitHub Environment, which changes the sub claim
  "repo:Agrovesto@101108012/infrastructure@1360104538:environment:dev",
]

# The role was not created by this module, so its policy may not be named
# "<role>-policy". List what is attached first:
#   aws iam list-attached-role-policies --role-name nomaos-dev-github-terraform
# - AdministratorAccess attached -> deploy_admin_access = true
# - a "<role>-policy" customer policy -> leave false and import_deploy_policy = true
deploy_admin_access  = true # checked 2026-09-24: only AdministratorAccess attached, no inline policies
import_deploy_policy = false

# Match the live bucket (import plan 2026-09-23: SSE-KMS with bucket key,
# rule "retention-and-incomplete-uploads", noncurrent 365 days).
state_lifecycle_rule_id  = "retention-and-incomplete-uploads"
state_noncurrent_days    = 365
state_bucket_kms_key_arn = "arn:aws:kms:eu-west-1:353833416626:key/31f57b1f-cbde-4aa6-8c6e-18e129c80fb6"
