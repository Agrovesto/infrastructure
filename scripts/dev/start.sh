#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
exec 9>/run/agrovesto-runtime.lock
flock -w 900 9
cd /opt/agrovesto
mountpoint -q /srv/mssql || { echo 'DB disk is not mounted; refusing to start.' >&2; exit 1; }
export AWS_DEFAULT_REGION
AWS_DEFAULT_REGION=$(jq -er .region runtime.json)
install -d -m 0700 /run/agrovesto
python=/opt/agrovesto/venv/bin/python
"$python" database.py prepare-dev --config runtime.json
while IFS= read -r registry; do
  aws ecr get-login-password --region "$AWS_DEFAULT_REGION" | docker login --username AWS --password-stdin "$registry"
done < <(jq -r '.image_registries[]' runtime.json)
# Create env files before Compose parses them. Their final secret values are
# populated only after the database logins are provisioned.
while IFS= read -r name; do
  touch "/run/agrovesto/$name.env"
  chmod 0600 "/run/agrovesto/$name.env"
done < <(jq -r '.services | keys[]' runtime.json)
docker compose -f compose.yaml pull
docker compose -f compose.yaml up -d mssql
"$python" database.py provision --config runtime.json
"$python" database.py render-dev-env --config runtime.json
docker compose -f compose.yaml up -d --remove-orphans
