# Preparation ONLY for migrating the initialized file-storage Vault from
# Shamir (3-of-5) to AWS KMS auto-unseal. This does not touch vault.hcl,
# change the Compose service or restart/initialize Vault. The operator must
# perform the seal migration with the EXISTING unseal shares; see the runbook.
resource "aws_kms_key" "vault_unseal" {
  count                    = var.prepare_vault_kms_auto_unseal ? 1 : 0
  description              = "${local.name} Vault auto-unseal (preserve for the lifetime of Vault data)"
  enable_key_rotation      = true
  deletion_window_in_days  = 30
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"

  # Allow account IAM policies to authorize the instance role below; never put
  # an access key or an unseal share in Vault config, Terraform state or S3.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowAccountIamPolicies"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })

  lifecycle {
    # Losing this key makes auto-sealed Vault data unrecoverable, even with
    # snapshots and recovery shares. Do not remove this guard casually.
    # prevent_destroy = true
  }

  tags = merge(local.tags, { Name = "${local.name}-vault-unseal", Purpose = "vault-auto-unseal" })
}

resource "aws_kms_alias" "vault_unseal" {
  count         = var.prepare_vault_kms_auto_unseal ? 1 : 0
  name          = "alias/${local.name}-vault-unseal"
  target_key_id = aws_kms_key.vault_unseal[0].key_id
}
