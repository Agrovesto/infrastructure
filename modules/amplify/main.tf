resource "aws_amplify_app" "this" {
  for_each = var.apps

  name       = each.key
  repository = each.value.repository
  platform   = "WEB"

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
            - npm ci
        build:
          commands:
            - npm run build
      artifacts:
        baseDirectory: build
        files:
          - '**/*'
      cache:
        paths:
          - node_modules/**/*
  EOT

  tags = merge(var.tags, { App = each.key })
}

resource "aws_amplify_branch" "this" {
  for_each = var.apps

  app_id            = aws_amplify_app.this[each.key].id
  branch_name       = each.value.branch
  stage             = "DEVELOPMENT"
  framework         = each.value.framework
  enable_auto_build = each.value.enable_auto_build

  tags = var.tags
}

resource "aws_amplify_domain_association" "this" {
  for_each = var.enable_custom_domain ? var.apps : {}

  app_id      = aws_amplify_app.this[each.key].id
  domain_name = var.domain_name

  sub_domain {
    branch_name = aws_amplify_branch.this[each.key].branch_name
    prefix      = each.value.subdomain
  }

  wait_for_verification = false
}
