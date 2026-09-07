# Operations, recovery and maintenance

**Scope:** these are operator procedures, not actions executed by a PR or an unattended infrastructure push. Use authorized SSO sessions, verify the AWS account before every operation, record resource IDs and changes, and never paste credentials, state or signed URLs into tickets/chat. Validate recovery in disposable databases/volumes before touching live data.

## Inspecting dev safely

Get the instance ID from dev Terraform outputs or the EC2 console. There is no SSH key/security-group rule. Use Systems Manager Session Manager with a separately authorized operator identity:

```bash
aws --profile agrovesto-dev-admin sts get-caller-identity
aws --profile agrovesto-dev-admin ssm start-session --target i_REAL_DEV_INSTANCE
```

On the host, elevate through the authorized SSM session and inspect:

```bash
sudo systemctl status agrovesto.service agrovesto-backup.timer
sudo journalctl -u agrovesto.service -u agrovesto-backup.service --since today
sudo findmnt /srv/mssql
sudo lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL
sudo docker compose -f /opt/agrovesto/compose.yaml ps
```

Do not run `docker compose config`, `docker inspect`, `env`, `set -x` or verbose AWS CLI debug logging where secret-bearing container environments could be captured in logs. SQL passwords are not in user data/SSM documents, but are necessarily visible to trusted root/container administrators at runtime.

The installer:

- Finds the requested EBS disk by its **volume ID/serial**, not Nitro device order.
- Refuses unexpected signatures/partitions/filesystems; formats only a blank device, without `mkfs -f`.
- Mounts `/srv/mssql` by UUID, checks an existing mount matches, and grows XFS after an approved EBS size increase.
- Keeps SQL Server's data/log/secrets/backup directories on that mount, owned by UID 10001.
- Uses a systemd mount dependency and a separate `mountpoint` guard before startup. A missing disk cannot silently turn the OS disk into the database disk.
- Uses `nofail` in fstab so an attachment failure does not prevent SSM recovery of the host; **applications still fail closed**.

AMI lookup is ignored for routine drift so a newly published AMI does not surprise-replace the host. Guest package and Docker/Compose updates happen on configuration convergence; review/test them in dev. Enable a controlled Systems Manager patching/maintenance policy as an additional operational control. The current stack does not define unattended patch windows.

## Dev backups

The systemd timer runs daily at 02:30 UTC, including a missed execution after boot (`Persistent=true`). SQL remains online during native backup:

1. `BACKUP DATABASE ... WITH COPY_ONLY, COMPRESSION, CHECKSUM, INIT` for **each configured database**.
2. `RESTORE VERIFYONLY ... WITH CHECKSUM`.
3. SHA-256 calculation and SSE-KMS upload to `sqlserver/<UTC timestamp + random suffix>/<database>.bak`.
4. Upload a manifest listing names, keys, sizes and SHA-256 values.
5. Emit `agrovesto/Backups / DatabaseBackupSuccess` with `Environment=dev`.

A failed SQL operation/upload exits nonzero. Successful upload permits local file removal; failed upload retains its `.bak` for diagnosis/retry. Failed partial files can exhaust the SQL disk: inspect before removing abandoned **backup files only**, never SQL data/log files. Capacity must include the largest native backup staging requirement. The program does not delete or export undeclared/system databases; the disk snapshot covers the entire mounted volume.

Trigger a backup intentionally:

```bash
# On the dev host through an authorized SSM session:
sudo systemctl start agrovesto-backup.service
sudo journalctl -u agrovesto-backup.service -n 100
```

From your operator workstation, inspect the S3 manifest and AWS Backup recovery points:

```bash
aws --profile agrovesto-dev-admin s3 ls s3://REAL_DEV_BACKUP_BUCKET/sqlserver/
aws --profile agrovesto-dev-admin backup list-recovery-points-by-backup-vault \
  --backup-vault-name agrovesto-dev-database
```

The host can read/write **its own** native-backup prefix for backup/restoration, but cannot delete objects or bypass retention. It can read versioned deployment artifacts; it cannot read Terraform state or production data. Governance Object Lock is a guardrail, not protection from every account administrator.

EBS snapshots run separately at 04:00 UTC. They are **crash-consistent**; SQL recovery may replay logs after a restore. Neither daily snapshots nor daily full native backups promise point-in-time recovery between backups in dev. The OS disk is intentionally rebuilt from infrastructure/configuration, not included in the database snapshot selection.

## Restore drill: native dev backup

Restore to a **new** database first, never overwrite the active one as a smoke test.

1. Select a completed timestamp with a manifest; record S3 object **version IDs**, not only keys. Retrieve the object with your authorized identity, or on the host using its own prefix read permission. KMS key access is required.
2. Verify the SHA-256 matches the manifest. Transfer to `/srv/mssql/backup/` with owner `10001:0` and mode 0640; ensure free space. Do not store it under the root filesystem or a public bucket.
3. Retrieve the dev admin secret directly into a short-lived process environment without displaying it. Keep session auditing enabled; do not type/paste password values into a recorded shell. The `sa` password is stored in `agrovesto/dev/sql/admin`. Do not pass it with `sqlcmd -P` or place it in a SQL file. Set `SQLCMDPASSWORD` in the temporary process environment.
4. Execute `RESTORE FILELISTONLY` through `docker exec` to get logical file names. **Do not guess them.** Then restore under a new name and new paths, using each logical file's `MOVE` clause.

Illustrative SQL only; replace logical names with the actual `FILELISTONLY` result:

```sql
RESTORE FILELISTONLY FROM DISK = N'/var/opt/mssql/backup/selected.bak';
GO
RESTORE DATABASE [RestoreCheck_Api]
  FROM DISK = N'/var/opt/mssql/backup/selected.bak'
  WITH MOVE N'ACTUAL_LOGICAL_DATA_NAME' TO N'/var/opt/mssql/data/RestoreCheck_Api.mdf',
       MOVE N'ACTUAL_LOGICAL_LOG_NAME' TO N'/var/opt/mssql/log/RestoreCheck_Api.ldf',
       RECOVERY, CHECKSUM;
GO
DBCC CHECKDB ([RestoreCheck_Api]) WITH NO_INFOMSGS;
GO
```

Execute via `/opt/mssql-tools18/bin/sqlcmd -N -C -b -x` **inside the dev container**. `-C` is allowed only for dev's self-signed certificate. No host port 1433 is published; ordinary SSM port-forwarding to EC2:1433 is not an available GUI connection path.

5. Check table counts, expected transactions and application compatibility. `VERIFYONLY` does not perform `DBCC CHECKDB` or an application test.
6. For an actual recovery/cutover, stop application writes first, agree the accepted data-loss window, restore/reconcile login mappings, run migrations and test before reopening traffic. No restore command here uses `WITH REPLACE` or drops an active database automatically.
7. Unset temporary password environment variables and remove local restore files when no longer needed. Record restore duration and evidence without secret values.

## Restore drill: the dev EBS disk

Prefer a disposable restore volume/isolated test host for the first drill. Preserve the original volume and original secret versions.

For an approved actual replacement on the existing host:

1. Stop `agrovesto-backup.timer`, any backup service and `agrovesto.service`; disable their automatic restart during maintenance. Ensure SQL stopped cleanly and unmount `/srv/mssql`. Keep the host available through SSM. Never detach a mounted live DB filesystem or use force detach.
2. Create a new encrypted gp3 EBS volume from the chosen recovery point/snapshot in **the EC2 instance's AZ**. Use the same intended KMS key and at least the previous volume size. An AWS Backup restore requires a separately authorized restore role; the supplied backup role is a backup role, not an unrestricted restore role.
3. Detach the old unmounted data volume, keep it quarantined, and attach the restored volume as the requested `/dev/sdf`. Identify it by volume ID, not Linux enumeration.
4. Back up remote Terraform state to approved encrypted storage. Under maintenance ownership (no concurrent CI), remove **only** the old attachment/data-volume addresses from state, then import the restored volume and attachment into those addresses. `state rm` does not delete the old AWS volume; inventory and protect it separately.

```bash
# Use the correct DEV profile/backend and REAL IDs; do not blindly paste this.
terraform -chdir=environments/dev state rm 'module.host.aws_volume_attachment.database'
terraform -chdir=environments/dev state rm 'module.host.aws_ebs_volume.database'
terraform -chdir=environments/dev import -var-file=terraform.tfvars \
  'module.host.aws_ebs_volume.database' vol_RESTORED
terraform -chdir=environments/dev import -var-file=terraform.tfvars \
  'module.host.aws_volume_attachment.database' '/dev/sdf:vol_RESTORED:i_REAL_INSTANCE'
```

5. Verify the restored filesystem UUID. Remove/update only the obsolete `/srv/mssql` fstab entry during maintenance; the installer intentionally refuses a conflicting UUID. Do not format the restored disk. The root mountpoint must be empty when unmounted.
6. Ensure the correct **historical admin secret version** is available: SQL's existing `sa` password does not change just because `MSSQL_SA_PASSWORD` is set in an environment file. An EBS restore can roll back `sa`/login passwords. Never generate a new secret and assume it unlocks an old disk.
7. Review the plan with the restored size/AZ/key. A reviewed dev push updates the versioned runtime configuration with the newly imported volume ID and triggers SSM convergence. User-data updates may stop/start the instance; expect downtime. The installer remounts, verifies and starts SQL before APIs.
8. Validate SQL recovery, `DBCC CHECKDB`, application readiness, both disk metrics and a fresh native backup. Only after acceptance should old data be disposed of through the retention/decommission procedure.

`prevent_destroy` and the plan guard deliberately prevent Terraform from casually deleting/replacing the original database volume. Removing protections without a state/restore plan is not a recovery strategy.

## RDS recovery and native S3 operations

### Point-in-time recovery (preferred for prod incidents)

RDS retains 35 days of automatic backups and supports restoration within its actual earliest/latest restorable times. A restore creates a **new DB instance**, not an in-place rewind:

1. Stop/contain writes, choose the approved restore time and record the expected RPO.
2. Restore through RDS to a **new identifier**, retaining encryption, the isolated subnet group, the DB security group, non-public access and the intended Multi-AZ/edition/class. Confirm snapshot/log availability in AWS; a configured retention period is not proof of completed backups.
3. Verify parameters/options, TLS/CA, native-backup role, maintenance/backups, monitoring and master credential management on the restored instance. Add any settings not inherited by the restore.
4. Keep the old instance for investigation and rollback. Under approved maintenance ownership, back up state, relinquish only the old `module.database.aws_db_instance.this` state address and import the restored instance into it. Set **`rds_identifier`** to the restored name in reviewed prod inputs so Terraform does not rename it back. Do not leave the restored and original instances ambiguously owned by the same state address.
5. Review the plan: it must not propose another RDS replacement. The normal stateful-resource guard remains in force. Retain old CloudWatch logs before changing identifiers/log group names; those names include the instance identifier.
6. After restoring server/database login state, reconcile API secrets/passwords and user SIDs with the private admin task. The RDS managed master secret may be different from the original. Application secret values are deliberately outside RDS backups, so account for rotations since the restore point.
7. Push the reviewed endpoint/configuration change so ECS task definitions use the new actual RDS hostname and roll forward. Do not use a vanity DNS alias with certificate verification disabled to hide the cutover.
8. Run integrity and application tests, verify traffic and backups, then dispose of the quarantined old instance only after the approved retention period. Track resources removed from state explicitly—they are still chargeable AWS resources.

Restore adoption is an exceptional state operation, not a `terraform apply -replace` of the only live database.

### Native `.bak` via the configured S3 option

The RDS option group includes `SQLSERVER_BACKUP_RESTORE` with a role limited to the prod native-backup bucket and environment KMS key. The bucket is private, versioned and retained. Native production backups are **on demand**; the automated guarantee is RDS backups/PITR.

From an **authorized SQL client with private RDS connectivity** (VPN/controlled maintenance runner, or an explicitly reviewed one-off administration task), examples are:

```sql
-- Use the actual bucket and a unique key. Inherit the bucket's SSE-KMS default.
EXEC msdb.dbo.rds_backup_database
  @source_db_name = N'AgrovestoApi',
  @s3_arn_to_backup_to = N'arn:aws:s3:::REAL_PROD_BACKUP_BUCKET/native/UNIQUE-api.bak',
  @type = N'FULL',
  @overwrite_s3_backup_file = 0,
  @enable_bucket_default_encryption = 1;
GO
EXEC msdb.dbo.rds_task_status;
GO

-- Drill only: new DB name, never overwrite the live application database.
EXEC msdb.dbo.rds_restore_database
  @restore_db_name = N'RestoreCheck_Api',
  @s3_arn_to_restore_from = N'arn:aws:s3:::REAL_PROD_BACKUP_BUCKET/native/UNIQUE-api.bak';
GO
EXEC msdb.dbo.rds_task_status;
GO
```

These RDS procedures are **asynchronous**. Poll the returned task ID with `rds_task_status` and require lifecycle `SUCCESS`; a procedure returning without error is not completed backup/restore. Review native backup restrictions, engine/version/edition compatibility and option support before moving dev Developer backups into Standard RDS. Backups using Enterprise-only features may not restore to Standard.

No production bastion/public SQL port or unrestricted SQL console is provisioned. `run-sql-admin.sh` is intentionally limited to the supplied database/login provisioning program, not arbitrary ad-hoc SQL. Arrange private operator connectivity or extend the one-off job through a reviewed, tested maintenance change; never expose RDS to the public internet just to run a restore.

## Credentials and schema changes

### First creation

Dev generates an admin secret only for an uninitialized DB disk, then creates per-API credentials and idempotent databases/logins. Prod RDS supplies its own managed master secret; the one-off ECS admin task creates the API secrets/logins. The program never logs SQL/passwords or supplies `sqlcmd -P`, validates identifiers and escapes SQL literals, disables sqlcmd variable expansion/startup scripts and refuses control-character batch injection.

### Runtime privileges and migrations

Application logins have reader/writer/execute permissions, not DDL. Your application repository must implement versioned, tested migrations using a controlled migration identity/task. Do not give every API `sa`, the RDS master password, or `db_owner` simply because a framework attempts migrations on startup. Removing a map key does not issue `DROP DATABASE` or `DROP LOGIN`.

### Coordinated password changes (not automatic rotation)

RDS rotates its **master** secret through AWS. API secrets and dev `sa` do not have an independent Lambda rotation schedule in this baseline; rotating the JSON alone would break running applications or lock a recovered dev disk.

For a controlled API-login password change:

1. Plan a maintenance/rollout window and record the current Secrets Manager version for rollback. Stop/contain writes if a rolling credential change is not supported by the application.
2. Create the reviewed new secret version with the **same `username` and `database`**, strong password, and no CR/LF/NUL/control characters. Never generate it in Terraform or echo it in logs. This simple single-user procedure has a mismatch window until SQL is updated; choose a dual-login rotation design if you require uninterrupted availability.
3. Explicitly reconcile SQL to the current secret, and confirm success:

```bash
# DEV, on host through authorized SSM (under the runtime lock):
sudo flock -w 1200 /run/agrovesto-runtime.lock \
  /opt/agrovesto/venv/bin/python /opt/agrovesto/database.py provision \
  --config /opt/agrovesto/runtime.json --sync-passwords

# PROD, from the correct operator account:
AWS_PROFILE=agrovesto-prod-admin scripts/run-sql-admin.sh environments/prod --sync-passwords
```

4. Dev: restart `agrovesto.service` to rebuild `/run` env files and reconcile containers. Prod: force a new deployment of the affected ECS services, using an authorized application release/operator identity, and wait for healthy tasks. ECS injects secret values only at task start; updating Secrets Manager alone does not refresh them.
5. Verify application logins and backup/monitoring. If synchronization fails, preserve versions, stop new rollouts, restore the prior secret version and reconcile SQL before restarting clients. The normal provisioning mode intentionally does **not** change existing login passwords; `--sync-passwords` is an explicit privileged action.

Dev `sa` rotation requires a DBA-coordinated SQL `ALTER LOGIN` and matching Secrets Manager update using the old authorized session. Do not rotate `MSSQL_SA_PASSWORD` in the environment and expect an existing SQL data directory to adopt it. Historical full-disk restores also need historical admin-secret access.

## Image promotion and rollback

- ECR repository resource policies grant the peer account only `BatchGetImage`, `GetDownloadUrlForLayer` and `BatchCheckLayerAvailability`. The pulling EC2/ECS role also needs those actions plus `GetAuthorizationToken` on `*`.
- ECR manages its KMS encryption on the service side; a peer image pull is not a grant to decrypt arbitrary objects with the other account's KMS key.
- Production may reference a scanned **dev digest** directly, or copy it into prod using separately authorized publisher credentials for each registry. Verify the digest after copying. There is no automatic ECR replication rule.
- Retain a release tag on every deployed digest. The lifecycle rule removes **only untagged images after 30 days**; tagged images are retained. Deleting a dev release tag can eventually break a prod digest-only pull even while an already-running container still works.
- Roll back application code by updating to a known-good retained digest and making a reviewed push. ECS has a deployment circuit breaker with rollback. Schema/data changes need a separate compatibility/rollback plan and are not undone by an image rollback.

## Host, capacity and version changes

- Raise the dev SQL volume size in inputs, review cost, push: EBS grows and the installer grows XFS. EBS cannot shrink in place; a shrink needs a migration to another volume.
- Monitor both root/SQL disk fullness. Docker images/unused layers consume the root disk; plan conservative image cleanup without deleting the active or rollback releases. Do not run broad `docker system prune --volumes` as a backup strategy.
- AMI replacement requires an approved downtime procedure: back up, stop SQL, detach the data disk cleanly, retain the volume/secret, disable termination protection only for the approved instance, and review the replacement/reattachment plan. Do not let instance replacement format the data volume. SQL/API readiness and SSM status must be checked after reattachment.
- Increase API memory/EC2 capacity together with the SQL memory reservation. Default dev capacity is not an unlimited number of services.
- Pin the resolved RDS 2022 engine build before live production and test permitted minor updates. The null lookup follows the AWS default within the SQL Server 2022 family; it can change. Check pending maintenance/parameter reboots. Major upgrades need explicit design/testing and are disallowed by default.
- Review provider/Terraform, Compose, SQL CU, Python base, Microsoft tools and scanner pins. Updates can change pricing, available instance types, schemas and scan results. Run the complete pipeline and restore drills, not only `fmt`.

## Alerts and incidents

Confirm SNS email subscriptions and test alarm delivery deliberately. Inspect encrypted CloudWatch logs, dashboards and EventBridge target delivery metrics. GuardDuty findings >=4, failed AWS Backup jobs and ECS deployment failures go to SNS. Unauthorized API-call logs have a CloudWatch metric alarm. RDS emits availability/failure/failover/storage/maintenance notifications.

Budgets monitor total account spend, not only tagged resources, so orphaned/unmanaged recovery resources are visible too. They are delayed alerts, not automatic shutdown. Missing backup heartbeat, stopped EC2 or missing CWAgent metrics should not be treated as harmless silence.

## Decommissioning and regional DR

Turning `services_enabled=false` removes production ECS services (retains task definitions/data) or stops dev API containers; it **does not** stop baseline NAT/ALB/RDS/EC2 charges. RDS Multi-AZ is not regional disaster recovery.

Before decommissioning:

1. Obtain data-owner/cost-owner approval and a retention/legal review.
2. Take independent backups and perform a successful restore drill; ensure keys and secret versions survive for the retention period.
3. Remove/redirect traffic safely, including DNS, Amplify and clients. Preserve historical logs.
4. In a reviewed maintenance change, explicitly handle `prevent_destroy`, RDS/ALB/EC2 deletion protection, unique final-snapshot naming, S3 versions/delete markers and Backup/Object Lock retention. The normal plan guard rejects protected data deletion and must not be bypassed casually.
5. Keep state/audit/backup encryption keys and bootstrap infrastructure until their consumers and recovery obligations are gone. Do not force-empty buckets or schedule KMS deletion to make a destroy succeed.
6. Inventory recovery resources no longer in state and dispose of them separately when authorized.

For stronger DR, add tested cross-region/cross-account backup copies (with compatible KMS policies), independent recovery roles, immutable retention according to policy, restore automation and documented RPO/RTO. Customer S3 backups and EBS snapshots in this baseline remain in their own account/region. Do not call this regional failover-ready until a real end-to-end restore proves it.
