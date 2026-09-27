# SSM SecureStrings for the opt-in GitHub OAuth -> Dex -> existing Vault OIDC flow.
# Do not change the running file-storage Vault's seal, volume or server config.
resource "aws_ssm_parameter" "vault_github_client_id" {
  count  = var.vault.oidc_enabled ? 1 : 0
  name   = "/${local.name}/vault_github_client_id"
  type   = "SecureString"
  value  = var.vault_github_client_id
  key_id = aws_kms_key.host_passwords.arn
  tags   = local.tags
}

resource "aws_ssm_parameter" "vault_github_client_secret" {
  count  = var.vault.oidc_enabled ? 1 : 0
  name   = "/${local.name}/vault_github_client_secret"
  type   = "SecureString"
  value  = var.vault_github_client_secret
  key_id = aws_kms_key.host_passwords.arn
  tags   = local.tags
}

resource "aws_ssm_parameter" "vault_oidc_client_secret" {
  count  = var.vault.oidc_enabled ? 1 : 0
  name   = "/${local.name}/vault_oidc_client_secret"
  type   = "SecureString"
  value  = var.vault_oidc_client_secret
  key_id = aws_kms_key.host_passwords.arn
  tags   = local.tags
}
