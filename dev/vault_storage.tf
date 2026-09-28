# Opt-in for fresh Vault installations only; never an automatic data/seal migration.
variable "manage_fresh_vault" {
  type        = bool
  default     = false
  description = "Manage dedicated storage and KMS configuration for a fresh Vault. Existing root-disk data/config must be reviewed manually."
}

resource "aws_ebs_volume" "vault" {
  count             = var.manage_fresh_vault ? 1 : 0
  availability_zone = aws_subnet.public[0].availability_zone
  size              = 20
  type              = "gp3"
  encrypted         = true
  tags = merge(local.tags, {
    Name        = "${local.name}-vault-data"
    VaultBackup = local.name
  })
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = var.prepare_vault_kms_auto_unseal
      error_message = "Managed fresh Vault requires prepare_vault_kms_auto_unseal = true."
    }
  }
}

resource "aws_volume_attachment" "vault" {
  count                          = var.manage_fresh_vault ? 1 : 0
  device_name                    = "/dev/sdi"
  volume_id                      = aws_ebs_volume.vault[0].id
  instance_id                    = aws_instance.app.id
  stop_instance_before_detaching = true
}

resource "aws_iam_role" "vault_snapshots" {
  count = var.manage_fresh_vault ? 1 : 0
  name  = "${local.name}-vault-snapshots"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "dlm.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "vault_snapshots" {
  count      = var.manage_fresh_vault ? 1 : 0
  role       = aws_iam_role.vault_snapshots[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "vault" {
  count              = var.manage_fresh_vault ? 1 : 0
  description        = "Daily crash-consistent Vault volume snapshots; retain 14"
  execution_role_arn = aws_iam_role.vault_snapshots[0].arn
  state              = "ENABLED"
  policy_details {
    resource_types = ["VOLUME"]
    target_tags    = { VaultBackup = local.name }
    schedule {
      name = "daily"
      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["19:00"]
      }
      retain_rule { count = 14 }
      copy_tags = true
    }
  }
  tags       = local.tags
  depends_on = [aws_iam_role_policy_attachment.vault_snapshots]
}

output "vault_data_volume_id" {
  value = var.manage_fresh_vault ? aws_ebs_volume.vault[0].id : ""
}
