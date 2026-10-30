#!/usr/bin/env bash
# Attach Vault to the external network used by the independently deployed
# blue/green APIs. Keep this post-Compose so refreshing Vault's container
# definition does not itself cause a restart just to change its networks.
set -Eeuo pipefail

network="nomaos_edge"
container="agrovesto-vault"

fail() { printf 'Vault network setup failed: %s\n' "$1" >&2; exit 1; }

docker network inspect "$network" >/dev/null 2>&1 || fail "Docker network $network does not exist"
[[ "$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || true)" == true ]] || fail "Vault container is not running"

network_json="$(docker inspect -f '{{json .NetworkSettings.Networks}}' "$container")"
network_state="$(python3 - "$network_json" "$network" <<'PY'
import json
import sys
try:
    networks = json.loads(sys.argv[1])
except (IndexError, json.JSONDecodeError):
    raise SystemExit("invalid")
settings = networks.get(sys.argv[2])
if settings is None:
    print("missing")
elif "vault" in settings.get("Aliases", []):
    print("ready")
else:
    print("conflict")
PY
)"

case "$network_state" in
  ready)
    exit 0
    ;;
  missing)
    docker network connect --alias vault "$network" "$container"
    ;;
  *)
    fail "Vault is attached to $network without the expected 'vault' DNS alias; review the network manually"
    ;;
esac
