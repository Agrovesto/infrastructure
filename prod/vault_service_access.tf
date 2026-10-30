# =============================================================================
# Per-service Vault access for the production ECS APIs
#
# The application paths and AppRole credentials are deliberately distinct per
# ECS service. Secret containers are created here without values; an operator
# provisions role_id/secret_id after Vault is initialized, using
# configure-vault-services.sh. Terraform never stores the AppRole SecretIDs.
# =============================================================================

locals {
  vault_kv_mount         = "kv"
  vault_path_environment = "prod"
  vault_service_paths    = {
    for service in keys(var.services) :
    service => "${local.vault_kv_mount}/${service}/${local.vault_path_environment}/appsettings"
  }
}

resource "aws_secretsmanager_secret" "vault_service_credentials" {
  for_each = var.enable_vault ? var.services : {}

  name                    = "${local.name}/${each.key}/vault-approle"
  description             = "AppRole credentials for ${each.key} to access its own production Vault path"
  recovery_window_in_days = 30

  tags = merge(local.tags, { Service = each.key })
}
