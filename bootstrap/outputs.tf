# =============================================================================
# Outputs — bootstrap
# =============================================================================

output "state_bucket_name" {
  value       = aws_s3_bucket.state.id
  description = "Goes into prod/versions.tf (backend bucket)"
}

output "deploy_role_arn" {
  value       = aws_iam_role.deploy.arn
  description = "Goes into the AWS_ROLE_ARN_PROD GitHub secret"
}

output "oidc_provider_arn" {
  value       = local.oidc_provider_arn
  description = "The GitHub Actions OIDC provider in this account"
}

output "next_steps" {
  description = "Copy/paste the remaining wiring (also in bootstrap/README.md)"
  value       = <<-EOT

    1. Point the prod backend at the state bucket:

         sed -i 's/PROD_ACCOUNT_ID/${data.aws_caller_identity.current.account_id}/' ../prod/versions.tf

       (replacing this value: ${local.state_bucket_name})

    2. Store the deploy role ARN as the prod workflow secret:

         gh secret set AWS_ROLE_ARN_PROD --body "${aws_iam_role.deploy.arn}"

       (or: repo Settings > Secrets and variables > Actions > New repository secret
        name AWS_ROLE_ARN_PROD, value ${aws_iam_role.deploy.arn})

    3. Install the workflow and let CI do the rest:

         cp ../prod.workflow.yml ../.github/workflows/prod.yml
         git add ../.github/workflows/prod.yml ../prod/versions.tf && \
           git commit -m "wire prod backend + deploy role" && git push

       Merging to main then runs prod.workflow.yml: plan on the PR,
       apply on push to main in the prod account.

  EOT
}
