# Dev Vault: prepare AWS KMS auto-unseal (manual seal migration)

The live EC2 Vault 1.15.6 is **already initialized** with file storage at `/data/vault/data` on the EC2 **root disk** and a Shamir seal (5 shares, threshold 3). Its Compose service reads `/data/vault/config/vault.hcl` from the same host. **Do not initialize it again, replace EC2, or switch storage backends.** The latest dev stack has `aws_instance.app.prevent_destroy = true`; that does not replace a real backup of the root volume.

Auto-unseal is a *seal migration*, not a cron job that stores the Shamir shares on the server. The Terraform variable `prepare_vault_kms_auto_unseal` defaults to `false`; `dev/terraform.auto.tfvars` now explicitly sets it to `true` to **prepare** a dedicated AWS KMS key and alias and grant the EC2 instance role `kms:Encrypt`, `kms:Decrypt`, and `kms:DescribeKey` on that key **only when an approved plan is applied**. Changing the file has not deployed anything. It does **not** modify `vault.hcl`, restart Vault, apply the new seal, or run the migration. Vault uses the instance role through IMDSv2 (the instance already allows two metadata hops); do not configure long-lived AWS credentials in the container.

## Preparation — no Vault restart

1. Plan a maintenance window. Have all **three existing Shamir unseal shares** available from their separate custodians, without copying them to this host or to Terraform. Confirm an encrypted, restorable backup of the root EBS volume. For consistency, take a snapshot while the instance is stopped, then restart and unseal Vault before proceeding. Confirm the Vault file data and config still exist after restart. Do not share the shares or privileged tokens in chat, SSM command logs, CI, or shell history.
2. Confirm `prepare_vault_kms_auto_unseal = true` in `dev/terraform.auto.tfvars` and run a Terraform plan. For this preparation, the expected AWS changes are **only** the KMS key, alias, and EC2 role policy update. This branch also contains other staged changes: **do not apply a plan that includes those or any EC2 replacement, new Vault volume, or Compose/Vault-config change**. Isolate the KMS preparation into a separately reviewed plan before applying. Keep the flag true thereafter (`prevent_destroy` protects the key in Terraform).
3. Get the key ARN with `terraform -chdir=dev output -raw vault_auto_unseal_key_arn`. The key is in the dev account and `var.aws_region` (currently `eu-west-1`); ensure the host's instance profile can use it before touching the live Vault config. KMS key rotation is enabled; disabling/deleting the key after migration can make Vault **unrecoverable even from backups**. Restrict IAM/KMS administration and monitor KMS availability. This dedicated customer-managed key adds an AWS charge.

## One-time, downtime-requiring Shamir → AWS KMS seal migration

**Do not run this until the key exists, the backup has been verified, and key custodians are present.** The seal stanza is deliberately *not* delivered from Terraform/S3: SSM config refresh must never migrate or restart this live Vault unexpectedly.

1. Through an administrative session, back up `/data/vault/config/vault.hcl` securely. Confirm it has no other `seal` stanza. **Append in place** to the existing host file (for example with `sudo tee -a`, which preserves the bind-mounted file's inode); do not swap the file via an atomic editor rename and then merely restart the existing container. Add one seal stanza, keeping its existing file `storage` and `listener` blocks intact:

   ```hcl
   seal "awskms" {
     region     = "eu-west-1"
     kms_key_id = "<vault_auto_unseal_key_arn output>"
   }
   ```

   No `access_key` or `secret_key` goes into the file. Use the **actual** ARN from the output, not the angle-bracket placeholder. A change to the seal configuration must be treated as a migration, not an ordinary config refresh.
2. Restart **only** the Vault container in the maintenance window: `sudo docker restart agrovesto-vault`. If the config file was replaced instead of changed in place, review the currently deployed Compose definition, then recreate only Vault (`sudo docker compose -f /opt/agrovesto/compose/docker-compose.yml up -d --no-deps --force-recreate vault`) to rebind the new host file. Check its logs and `sudo docker exec agrovesto-vault vault status`. Do not run `vault operator init`. If Vault cannot reach KMS or assumes the wrong AWS role, stop and diagnose; do not repeatedly experiment with key material or delete the KMS key. **Before entering any `-migrate` shares**, a failed start can be reverted by restoring the prior seal configuration and restarting with the existing shares. Once migration has begun, follow HashiCorp's migration recovery guidance rather than improvising a rollback.
3. Each of three authorized custodians runs `sudo docker exec -it agrovesto-vault vault operator unseal -migrate` and enters **one existing Shamir share interactively**. All three commands must include `-migrate`. Never put a share on the command line. On completion, Vault migrates those shares to **recovery keys**; retain them securely for privileged operations.
4. Check `vault status`: it should report `Seal Type: awskms`, `Initialized: true`, and `Sealed: false`; verify access to existing secrets. In the maintenance window, restart just that container once more and verify it unseals **without** entering shares. Preserve the recovery shares and the KMS key.

Auto-unseal handles normal startup/restart when AWS KMS, the key, network, and instance role are available. It does **not** guarantee recovery if the key is unavailable or permanently deleted. A Vault intentionally sealed via its API may remain sealed until an authorized restart or unseal action; do not add an automatic restart loop that defeats an operator-initiated emergency seal. AWS KMS auto-unseal also does not provide backups or HA for this single-node, root-disk-backed Vault.

References: [Vault seal migration](https://developer.hashicorp.com/vault/docs/concepts/seal#seal-migration) · [AWS KMS seal](https://developer.hashicorp.com/vault/docs/configuration/seal/awskms).
