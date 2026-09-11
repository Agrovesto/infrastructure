# =============================================================================
# IAM — GitHub Actions OIDC provider + Terraform deploy role
# =============================================================================

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = local.oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [for cert in data.tls_certificate.github_actions.certificates : cert.sha1_fingerprint]

  tags = local.tags
}

resource "aws_iam_role" "deploy" {
  name               = var.deploy_role_name
  description        = "Assumed by GitHub Actions (oidc/token.actions.githubusercontent.com) to terraform plan/apply the ${local.name} stack"
  assume_role_policy = data.aws_iam_policy_document.deploy_assume.json

  max_session_duration = 3600

  tags = local.tags
}

# Option A (default): scoped-but-generous policy covering the services the
# prod stack manages.
resource "aws_iam_policy" "deploy_scoped" {
  count = var.deploy_admin_access ? 0 : 1

  name        = "${var.deploy_role_name}-policy"
  description = "Terraform deploy permissions for the ${local.name} stack"
  policy      = data.aws_iam_policy_document.deploy_scoped.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "deploy_scoped" {
  count = var.deploy_admin_access ? 0 : 1

  role       = aws_iam_role.deploy.name
  policy_arn = aws_iam_policy.deploy_scoped[0].arn
}

# Option B: full admin (simplest — set deploy_admin_access = true).
resource "aws_iam_role_policy_attachment" "deploy_admin" {
  count = var.deploy_admin_access ? 1 : 0

  role       = aws_iam_role.deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
