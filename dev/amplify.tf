# =============================================================================
# AWS Amplify — frontends (landing, onboarding, ...)
# =============================================================================

resource "aws_amplify_app" "this" {
  for_each = var.amplify_apps

  name       = coalesce(each.value.name, each.key)
  repository = each.value.repository
  platform   = each.value.platform

  access_token = var.github_access_token != "" ? var.github_access_token : null

  enable_branch_auto_build    = each.value.enable_auto_build
  enable_branch_auto_deletion = true

  environment_variables = each.value.environment_variables

  build_spec = each.value.build_spec != null ? each.value.build_spec : <<-EOT
      version: 1
      frontend:
        phases:
          preBuild:
            commands:
              - npm ci --cache .npm --prefer-offline --legacy-peer-deps
          build:
            commands:
              - npm run build
        artifacts:
          baseDirectory: dist
          files:
            - "**/*"
        cache:
          paths:
            - .npm/**/*
  EOT

  tags = merge(local.tags, { App = each.key })

  lifecycle {
    # Adopted apps keep their existing build spec and environment. New apps
    # still get the build_spec above at creation. Tokens are write-only.
    ignore_changes = [build_spec, environment_variables, access_token, oauth_token]
  }
}

resource "aws_amplify_branch" "this" {
  for_each = var.amplify_apps

  app_id            = aws_amplify_app.this[each.key].id
  branch_name       = each.value.branch
  stage             = "DEVELOPMENT"
  framework         = each.value.framework
  enable_auto_build = each.value.enable_auto_build

  tags = local.tags
}

# Off by default: Route53 CNAMEs are used instead of Amplify domain association
# so multiple apps can share one parent domain without colliding.
resource "aws_amplify_domain_association" "this" {
  for_each = var.amplify_enable_custom_domain ? var.amplify_apps : {}

  app_id      = aws_amplify_app.this[each.key].id
  domain_name = var.domain_name

  sub_domain {
    branch_name = aws_amplify_branch.this[each.key].branch_name
    prefix      = each.value.subdomain
  }

  wait_for_verification = false
}
