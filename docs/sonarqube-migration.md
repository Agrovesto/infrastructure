# Migrating the old SonarQube (PostgreSQL) to the dev host

The new SonarQube runs with `sonarqube.database_engine = "postgres"` (see
`dev/terraform.auto.tfvars`): its own `agrovesto-sonarqube-db` container, data on the
SonarQube EBS volume (`/data/sonarqube/postgres`). A `pg_dump` of the old database is
restored into it and SonarQube upgrades the schema on first start. Projects, issue
history, users, groups, tokens, quality gates and profiles all carry over.

SonarQube cannot move data between PostgreSQL and SQL Server, which is why it
does not use the shared MSSQL container.

## 0. Check the old version

Find it in the old UI footer, or `curl -s http://OLD_HOST:9000/api/server/version`.

The new host runs `sonarqube:26.9.x-community`. SonarQube only upgrades a database
along its supported path, which passes through each LTA release:

| Old version | What to do |
|---|---|
| 9.9 LTA or newer | Restore straight into 26.9. |
| 8.9 LTA to 9.8 | Upgrade the old server to 9.9 LTA first (or do it here, see step 4b). |
| Older than 8.9 | Go to 8.9, then 9.9, then restore. |

Also note the **edition**. A Developer or Enterprise database cannot be downgraded
to Community.

## 1. Deploy the postgres change

Merge the branch into `dev`. The SSM refresh syncs the new compose file.
Before restoring, stop SonarQube so it does not create an empty schema first:

```bash
cd /opt/agrovesto/compose
sudo docker compose stop sonarqube
sudo docker compose up -d sonarqube-db
sudo docker exec agrovesto-sonarqube-db pg_isready -U sonarqube -d sonar
```

## 2. Dump the old database (old server)

```bash
# stop the old SonarQube so the dump is consistent
docker stop <old-sonarqube-container>
docker exec <old-postgres-container> pg_dump -U <old_user> -Fc --no-owner --no-acl <old_db> > sonar.dump
ls -lh sonar.dump
```

Also copy any third-party plugins you installed:
`<old-sonarqube>/extensions/plugins/*.jar`.

## 3. Move the dump to the dev host (no SSH needed)

```bash
# old server / laptop
aws s3 cp sonar.dump s3://<backup-bucket>/migration/sonar.dump --profile agrovesto-dev
# dev host (SSM session)
sudo aws s3 cp s3://<backup-bucket>/migration/sonar.dump /tmp/sonar.dump
```

The backup bucket name is in the `BACKUP_BUCKET` line of `/opt/agrovesto/compose/.env`.

## 4. Restore

```bash
# start from an empty database
sudo docker exec agrovesto-sonarqube-db psql -U sonarqube -d postgres \
  -c "DROP DATABASE IF EXISTS sonar;" -c "CREATE DATABASE sonar OWNER sonarqube;"

sudo docker cp /tmp/sonar.dump agrovesto-sonarqube-db:/tmp/sonar.dump
sudo docker exec agrovesto-sonarqube-db pg_restore -U sonarqube -d sonar \
  --no-owner --no-acl /tmp/sonar.dump
```

Remove the old Elasticsearch indexes so SonarQube rebuilds them from the restored DB:

```bash
sudo rm -rf /data/sonarqube/data/es*
```

Copy plugins (if any) to `/data/sonarqube/extensions/plugins/`, then
`sudo chown -R 1000:1000 /data/sonarqube/extensions`.

### 4a. Start and upgrade

```bash
sudo docker compose up -d sonarqube
sudo docker logs -f agrovesto-sonarqube   # wait for "SonarQube is operational"
```

Open **https://sonar.nomaos.com/setup** and click **Upgrade**. The schema migration
runs, then the ES reindex. Large instances can take a long time on this box.

### 4b. If the old version is too old

Temporarily set `image:` for `sonarqube` in `/opt/agrovesto/compose/docker-compose.yml`
to the intermediate LTA (e.g. `sonarqube:9.9-community`). Run 4a, and when `/setup`
has finished, set the image back to 26.9 and run 4a again. Redeploying from
Terraform restores the pinned image.

## 5. After the migration

- Log in with your **old** admin credentials. They are in the restored DB.
- Administration → General → Server base URL: `https://sonar.nomaos.com`.
- Scanner tokens carry over. Update the `SONAR_HOST_URL` secret in each repo to
  `https://sonar.nomaos.com` if it pointed at the old server.
- GitHub SSO settings from the old server are in the DB. Check their callback URL
  is `https://sonar.nomaos.com/oauth2/callback/github`.
- Backups: hosts built after this change include a nightly `pg_dump` in
  `backup-mssql.sh`. The current host predates it, so run one by hand for now:
  `sudo docker exec agrovesto-sonarqube-db pg_dump -U sonarqube -Fc sonar > /data/mssql/backup/sonarqube-pg-$(date +%F).dump`
- Keep the old server running, read-only, until you've checked the new one.
