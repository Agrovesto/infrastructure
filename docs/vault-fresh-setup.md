# Fresh dev Vault with Terraform-managed storage and KMS

This is **not a migration**. After the September 28 instance rebuild, the operator
confirmed the root-disk Vault data directory was empty and opted to start fresh.
The checked-in dev tfvars enables `manage_fresh_vault` and
`prepare_vault_kms_auto_unseal`. Both variables default to false for other users.
Do not enable fresh setup on an initialized root-backed Vault.

## What apply does

- Creates a protected, encrypted 20 GiB gp3 EBS volume in the host's AZ and attaches
  it at `/dev/sdi`. Nitro discovery uses the exact EBS serial, never attachment order.
- Publishes a non-secret config and setup script through the existing S3 config bucket.
  The config uses the Terraform KMS key ARN and region, file storage at `/vault/file`,
  and HTTP on the container network; host port 8200 stays localhost-only.
- Waits for attachment and role-policy delivery, then runs setup through the existing
  SSM association. This works on the current host without replacing EC2 or relying
  on a user-data rerun. The association waits up to 15 minutes for success.
- Refuses to hide root-disk files, mount over a running Vault, format a partitioned
  disk or one with another filesystem/signature, or replace a different config.
  Empty directories left by the broken Docker bind mounts may remain under the new
  mount; they are not deleted. Existing files require manual review, not deletion.
- Formats only a signature-free, unpartitioned expected volume, mounts it at
  `/data/vault`, and persists its UUID in fstab. Filesystem/conflict errors stop setup.
- Creates config only when data is empty; a matching config is left untouched on
  later runs. No recursive chown of stored secrets is performed.
- Installs a Docker systemd mount dependency and an updated config-sync service
  override. Reboots mount the disk before Docker's restart policies can start
  containers. Missing storage can therefore block Docker/other workloads too: this
  is deliberately fail-closed, not fallback to the root disk.
- Starts Compose via the existing refresh service. Review the entire plan because
  other changed service definitions can also be redeployed by that existing service.
- Schedules daily DLM snapshots at 19:00 UTC, retaining 14 snapshots. These add AWS
  volume/snapshot charges. They are **crash-consistent, not application-consistent**.

The Compose command is `server` only. HashiCorp's image entrypoint automatically
adds `-config=/vault/config`, which includes the mounted `vault.hcl`. Do not add
`-config=/vault/config/vault.hcl` as well: the duplicate load produces
`more than one enabled seal found`. Repair the Compose command and recreate the
container, not the KMS key or stored seal configuration.

Terraform never initializes Vault, stores recovery shares/root tokens, or calls
unseal. It does not automatically migrate a seal, copy old data, or approve config
changes. The config mount remains writable for compatibility with the image's root
entrypoint; keep administrative access restricted.

## Deploy

The checked-in domain/OIDC configuration also requires the credentials and explicit
restart approval in the [GitHub login guide](vault-github-login.md). Missing these
prerequisites deliberately blocks plans.

Keep Vault stopped for first setup. Run from the infrastructure checkout:

```bash
terraform -chdir=dev fmt -check
terraform -chdir=dev init
terraform -chdir=dev validate
terraform -chdir=dev plan -out=tfplan-vault
# Review: new Vault EBS/attachment, backup role/policy, config and SSM update.
# Existing KMS key must be retained. No EC2 replacement or data-volume destruction.
terraform -chdir=dev apply tfplan-vault
```

Do not commit saved plans. Terraform apply may finish AWS provisioning even if SSM
fails; inspect State Manager execution output before initializing. Fix the cause
and retry the association, rather than bypassing the guard. Root-owned setup is
run by SSM, so interactive `ssm-user` write permission is not needed.

On the host, verify:

```bash
findmnt /data/vault
lsblk -o NAME,SERIAL,FSTYPE,MOUNTPOINTS
docker logs --tail 80 agrovesto-vault
docker exec agrovesto-vault vault status
```

Compare the serial with `terraform -chdir=dev output -raw vault_data_volume_id`.
Expected fresh status: seal `awskms`, initialized `false`, sealed `true` (status
exit code 2 is normal while sealed). Fix KMS/IAM/IMDS/network errors first.

## Initialize manually once

Use a private administrative channel approved for sensitive output. **SSM session
logging can capture recovery shares and the root token**; do not send them through
SSM Run Command, CI, Terraform, chat, or shell redirection to shared files.

```bash
docker exec -it agrovesto-vault vault operator init -recovery-shares=5 -recovery-threshold=3
docker exec agrovesto-vault vault status
```

Secure shares with separate custodians and protect the root token. Expect
initialized true and sealed false. In a maintenance window, restart only Vault and
verify KMS auto-unseals. Configure application authentication/policies/secrets and
replace routine root-token use with least-privilege access.

## Backup and recovery obligations

Do not treat DLM as proof of recoverability. For an application-consistent backup,
stop Vault during an approved window, create a snapshot of this dedicated volume,
wait for snapshot completion, then start Vault again. Test restoration to an
isolated instance/volume (not the active mount), with the same KMS key available;
verify initialized status, unsealing and representative secrets. Scheduled live
snapshots can capture an in-progress multi-file update and require restore testing.
No restore test has been performed by this code change.

Preserve the auto-unseal key **and** the EBS encryption key for recovered volumes.
Recovery shares alone cannot decrypt data without the KMS key. Terraform guards do
not prevent console/API deletion, KMS disabling, removal of resource blocks, or
an administrator removing the guards. Do not disable either management flag once
used. Separate IAM controls, backup retention and restore drills remain necessary.

A replacement host must be in the volume's AZ. Plan attachment/detachment during
maintenance; `stop_instance_before_detaching` may stop the old host. Do not remove
EC2's existing prevent-destroy guard casually. For intentional config changes,
back up first, review storage/seal implications, and coordinate the deployed file
and generated template explicitly; routine refresh refuses differing configs.
