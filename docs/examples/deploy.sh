#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh — containerized blue/green deployment for NomaOS on EC2
#
# Usage:
#   deploy.sh --app <key>-api --image <ecr-ref> [options]
#
# Each app deploys behind its OWN nginx vhost (dev/<key>-api.nomaos.com, with
# two renames: nomaos -> dev-noma-api, serviceprovider -> dev-service-api).
# The vhost routes to the active slot through a map variable, resolved by
# nginx at request time, so a missing slot 502s its vhost and never takes the
# edge down. The slot file this script writes must therefore be the map
# format — a static `upstream` block makes nginx resolve at start-up and
# exit ("host not found in upstream") instead. See
# infrastructure/docs/blue-green-deployments.md.
#
# Port allocation (per app, no overlaps):
#   nomaos-api           blue 5007 / green 5008
#   wallet-api           blue 5009 / green 5010
#   onboarding-api       blue 5011 / green 5012
#   input-api            blue 5013 / green 5014
#   moneval-api          blue 5015 / green 5016
#   serviceprovider-api  blue 5017 / green 5018
#   agx-api              blue 5019 / green 5020
#
# Deployment flow:
#   1. Validate configuration
#   2. Pull immutable image
#   3. Start idle slot alongside live slot
#   4. Docker healthcheck
#   5. Application-local HTTP healthcheck inside candidate container
#   6. Nginx-container -> candidate HTTP healthcheck
#   7. EC2-host -> candidate HTTP healthcheck
#   8. Flip Nginx atomically (rewrite slot file map, nginx -t, reload)
#   9. Verify traffic through Nginx
#  10. Stop old slot
#  11. Retain Docker image cache
#
# IMPORTANT:
# Application health failures are NON-FATAL by default.
#
# Infrastructure failures remain FATAL:
#   - invalid arguments/config
#   - ECR/image pull failure
#   - Docker Compose startup failure
#   - nginx configuration failure
#   - nginx reload failure
#
# Exit codes:
#   0 = deployment completed
#   1 = deployment failed / rolled back
#   2 = usage error
# ─────────────────────────────────────────────────────────────────────────────
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────
APP_NAME=""
IMAGE=""
COMMIT_SHA=""
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-10}"
KEEP_OLD="${KEEP_OLD:-false}"
DRY_RUN=false
CONTINUE_ON_HEALTH_FAILURE="${CONTINUE_ON_HEALTH_FAILURE:-true}"
CHECK_DOCKER_HEALTH="${CHECK_DOCKER_HEALTH:-true}"
CHECK_CONTAINER_LOCAL="${CHECK_CONTAINER_LOCAL:-true}"
CHECK_NGINX_NETWORK="${CHECK_NGINX_NETWORK:-true}"
HOST_HEALTH_URL="${HOST_HEALTH_URL:-}"
CONTAINER_HEALTH_PATH="${CONTAINER_HEALTH_PATH:-/health/ready}"
EDGE_HEALTH_PATH="${EDGE_HEALTH_PATH:-/health}"
HEALTH_RETRIES="${HEALTH_RETRIES:-3}"
HEALTH_RETRY_INTERVAL="${HEALTH_RETRY_INTERVAL:-1}"
EDGE_RETRIES="${EDGE_RETRIES:-2}"
EDGE_RETRY_INTERVAL="${EDGE_RETRY_INTERVAL:-1}"
DRAIN_SECONDS="${DRAIN_SECONDS:-2}"
NGINX_CONTAINER="${NGINX_CONTAINER:-agrovesto-nginx}"

# ─────────────────────────────────────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: deploy.sh --app <name> --image <ref> [options]

Required:
  --app <name>
      App key. One of:
        nomaos-api  wallet-api  onboarding-api
        input-api   moneval-api  serviceprovider-api  agx-api

  --image <ref>
      Full immutable image reference.

      Examples:
        1234.dkr.ecr.eu-west-1.amazonaws.com/nomaos:abc123
        1234.dkr.ecr.eu-west-1.amazonaws.com/nomaos@sha256:abc123...

Options:
  --commit <sha>
      Commit SHA recorded for the deployment.

  --timeout <sec>
      Docker health gate timeout.
      Default: 10

  --keep-old
      Leave previous slot running after the traffic flip.

  --dry-run
      Print deployment plan and exit without changing anything.

  -h, --help
      Show this help.

Environment overrides:
  CONTINUE_ON_HEALTH_FAILURE=true|false
  CHECK_DOCKER_HEALTH=true|false
  CHECK_CONTAINER_LOCAL=true|false
  CHECK_NGINX_NETWORK=true|false
  HOST_HEALTH_URL=http://127.0.0.1:<port>/health/ready
  HEALTH_RETRIES=3
  HEALTH_RETRY_INTERVAL=1
  EDGE_RETRIES=2
  EDGE_RETRY_INTERVAL=1
  DRAIN_SECONDS=2
  EDGE_HEALTH_HOST=<fqdn>
      Host header for the post-flip edge check.
      Default: the app's own vhost, e.g. dev-wallet-api.nomaos.com
  DOMAIN_NAME=<domain>
      Zone used to build that default.
      Default: nomaos.com

Port allocation (per app):
  nomaos-api           blue 5007 / green 5008
  wallet-api           blue 5009 / green 5010
  onboarding-api       blue 5011 / green 5012
  input-api            blue 5013 / green 5014
  moneval-api          blue 5015 / green 5016
  serviceprovider-api  blue 5017 / green 5018
  agx-api              blue 5019 / green 5020
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Slot -> port mapping
#
# Ports are per app: the pairs are allocated in the dev infrastructure stack
# (dev/terraform.auto.tfvars, apis.<key>.blue_green) and documented in
# docs/blue-green-deployments.md. Never reuse a pair across apps.
# ─────────────────────────────────────────────────────────────────────────────
slot_port() {
  local slot="$1"
  case "${APP_NAME}:${slot}" in
    nomaos-api:blue)           echo 5007 ;;
    nomaos-api:green)          echo 5008 ;;
    wallet-api:blue)           echo 5009 ;;
    wallet-api:green)          echo 5010 ;;
    onboarding-api:blue)       echo 5011 ;;
    onboarding-api:green)      echo 5012 ;;
    input-api:blue)            echo 5013 ;;
    input-api:green)           echo 5014 ;;
    moneval-api:blue)          echo 5015 ;;
    moneval-api:green)         echo 5016 ;;
    serviceprovider-api:blue)  echo 5017 ;;
    serviceprovider-api:green) echo 5018 ;;
    agx-api:blue)              echo 5019 ;;
    agx-api:green)             echo 5020 ;;
    *)
      die "no blue/green port pair for app '${APP_NAME}' slot '${slot}'"
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# App -> vhost hostname mapping
#
# The nginx vhost each app deploys behind is the API's own hostname, which is
# NOT always "<key>-api.<domain>": nomaos serves dev-noma-api and
# serviceprovider serves dev-service-api. Keep in sync with
# dev/terraform.auto.tfvars (apis.<key>.subdomain).
# ─────────────────────────────────────────────────────────────────────────────
vhost_hostname() {
  local domain="${DOMAIN_NAME:-nomaos.com}"
  case "$1" in
    nomaos-api)          echo "dev-noma-api.${domain}" ;;
    serviceprovider-api) echo "dev-service-api.${domain}" ;;
    *-api)               echo "dev-${1}.${domain}" ;;
    *) die "unknown app '$1': expected <key>-api" ;;
  esac
}

is_managed_app() {
  case "$1" in
    nomaos-api | wallet-api | onboarding-api | input-api | moneval-api | serviceprovider-api | agx-api)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Parse arguments
# ─────────────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      APP_NAME="${2:?Missing value for --app}"
      shift 2
      ;;
    --image)
      IMAGE="${2:?Missing value for --image}"
      shift 2
      ;;
    --commit)
      COMMIT_SHA="${2:?Missing value for --commit}"
      shift 2
      ;;
    --timeout)
      HEALTH_TIMEOUT="${2:?Missing value for --timeout}"
      shift 2
      ;;
    --keep-old)
      KEEP_OLD=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Validate required arguments
# ─────────────────────────────────────────────────────────────────────────────
[[ -n "$APP_NAME" ]] || {
  usage >&2
  exit 2
}

is_managed_app "$APP_NAME" || {
  usage >&2
  die "unknown app '$APP_NAME': expected nomaos-api, wallet-api, onboarding-api, input-api, moneval-api, serviceprovider-api or agx-api"
}

[[ -n "$IMAGE" ]] || {
  usage >&2
  exit 2
}

if [[ "$IMAGE" != *:* && "$IMAGE" != *@* ]]; then
  die "--image must contain an explicit tag or digest; :latest is not allowed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Validate dependencies/configuration
# ─────────────────────────────────────────────────────────────────────────────
require_docker
load_app_env "$APP_NAME"

VAULT_KV_MOUNT="${VAULT_KV_MOUNT:-kv}"
UPSTREAM_NAME="${UPSTREAM_NAME:-${APP_NAME//-/_}}"
UPSTREAM_DIR="$NOMAOS_STATE_DIR/nginx/upstreams"
UPSTREAM_FILE="$UPSTREAM_DIR/${UPSTREAM_NAME}.conf"
COMMIT_SHA="${COMMIT_SHA:-unknown}"

# Host header for the post-flip edge check. The nginx default server answers
# 404 to any other name, and the vhost routes by Host — so the check must use
# the app's own hostname (the vhost that now fronts the slots).
EDGE_HEALTH_HOST="${EDGE_HEALTH_HOST:-$(vhost_hostname "$APP_NAME")}"

require_runtime_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || die "$name must be set in the application environment"
}

require_runtime_env "ASPNETCORE_ENVIRONMENT"
require_runtime_env "VAULT_ADDR"
require_runtime_env "VAULT_ROLE_ID"
require_runtime_env "VAULT_SECRET_ID"
require_runtime_env "VAULT_SECRET_PATH"
require_runtime_env "DB_CONNECTION_STRING"

# ─────────────────────────────────────────────────────────────────────────────
# Determine active and target slots
# ─────────────────────────────────────────────────────────────────────────────
ACTIVE="$(get_active_slot "$APP_NAME")"

case "$ACTIVE" in
  blue|green)
    ;;
  *)
    die "invalid active slot '$ACTIVE'; expected blue or green"
    ;;
esac

TARGET="$(other_slot "$ACTIVE")"

ACTIVE_CONTAINER="${APP_NAME}-${ACTIVE}"
TARGET_CONTAINER="${APP_NAME}-${TARGET}"

ACTIVE_PORT="$(slot_port "$ACTIVE")"
TARGET_PORT="$(slot_port "$TARGET")"

# APP_PORT is the candidate/target port.
APP_PORT="$TARGET_PORT"
export APP_PORT

# If the caller did not explicitly provide HOST_HEALTH_URL,
# automatically test the target slot's published localhost port.
if [[ -z "$HOST_HEALTH_URL" ]]; then
  HOST_HEALTH_URL="http://127.0.0.1:${TARGET_PORT}${CONTAINER_HEALTH_PATH}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Create required directories
# ─────────────────────────────────────────────────────────────────────────────
mkdir -p "$UPSTREAM_DIR" "$NOMAOS_STATE_DIR/logs/$APP_NAME/$TARGET"

# ─────────────────────────────────────────────────────────────────────────────
# Display deployment plan
# ─────────────────────────────────────────────────────────────────────────────
cat <<EOF

===============================================================
 NomaOS Blue/Green Deployment
===============================================================
 app             : $APP_NAME
 image           : $IMAGE
 commit          : $COMMIT_SHA
 environment     : $ASPNETCORE_ENVIRONMENT
 vault mount     : $VAULT_KV_MOUNT
 vault path      : $VAULT_SECRET_PATH

 live slot       : $ACTIVE
 live container  : $ACTIVE_CONTAINER
 live port       : $ACTIVE_PORT
 live state      : $(container_state "$ACTIVE_CONTAINER")

 target slot     : $TARGET
 target container: $TARGET_CONTAINER
 target port     : $TARGET_PORT

 upstream        : $UPSTREAM_FILE
 vhost           : $EDGE_HEALTH_HOST
 nginx container : $NGINX_CONTAINER

 docker health   : $CHECK_DOCKER_HEALTH
 local container : $CHECK_CONTAINER_LOCAL
 nginx network   : $CHECK_NGINX_NETWORK
 EC2 host check  : $HOST_HEALTH_URL

 continue health : $CONTINUE_ON_HEALTH_FAILURE
===============================================================

EOF

# ─────────────────────────────────────────────────────────────────────────────
# Dry run
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == true ]]; then
  info "dry run — nothing changed"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Compose helper
#
# Each slot gets its own deterministic port, looked up per app:
#
#   nomaos-api           blue 5007 / green 5008
#   wallet-api           blue 5009 / green 5010
#   onboarding-api       blue 5011 / green 5012
#   input-api            blue 5013 / green 5014
#   moneval-api          blue 5015 / green 5016
#   serviceprovider-api  blue 5017 / green 5018
#   agx-api              blue 5019 / green 5020
#
# This function deliberately calculates the port from the slot passed to it.
# ─────────────────────────────────────────────────────────────────────────────
compose_slot() {
  local slot="$1"
  local slot_port_value

  shift

  slot_port_value="$(slot_port "$slot")"

  IMAGE="$IMAGE" \
  APP_NAME="$APP_NAME" \
  SLOT="$slot" \
  APP_PORT="$slot_port_value" \
  COMMIT_SHA="$COMMIT_SHA" \
  NOMAOS_STATE_DIR="$NOMAOS_STATE_DIR" \
  ASPNETCORE_ENVIRONMENT="$ASPNETCORE_ENVIRONMENT" \
  VAULT_ADDR="$VAULT_ADDR" \
  VAULT_ROLE_ID="$VAULT_ROLE_ID" \
  VAULT_SECRET_ID="$VAULT_SECRET_ID" \
  VAULT_SECRET_PATH="$VAULT_SECRET_PATH" \
  VAULT_KV_MOUNT="$VAULT_KV_MOUNT" \
  DB_CONNECTION_STRING="$DB_CONNECTION_STRING" \
  REDIS_CONNECTION_STRING="${REDIS_CONNECTION_STRING:-redis:6379}" \
  LOG_FILE_PATH="${LOG_FILE_PATH:-/app/logs/nomaos-.log}" \
  docker compose \
    -p "${APP_NAME}-${slot}" \
    -f "$COMPOSE_DIR/docker-compose.app.yml" \
    "$@"
}

compose_target() {
  compose_slot "$TARGET" "$@"
}

# ─────────────────────────────────────────────────────────────────────────────
# Retry helper
# ─────────────────────────────────────────────────────────────────────────────
retry_command() {
  local label="$1"
  local attempts="$2"
  local interval="$3"
  shift 3

  local attempt

  for attempt in $(seq 1 "$attempts"); do
    if "$@"; then
      return 0
    fi

    log "   $label attempt $attempt/$attempts failed"

    if (( attempt < attempts )); then
      sleep "$interval"
    fi
  done

  return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# HTTP probe inside a container
# ─────────────────────────────────────────────────────────────────────────────
container_http_probe() {
  local container="$1"
  local url="$2"

  if docker exec "$container" sh -c 'command -v curl >/dev/null 2>&1'; then
    docker exec "$container" \
      curl \
      --fail \
      --silent \
      --show-error \
      --max-time 5 \
      "$url" \
      >/dev/null 2>&1
    return $?
  fi

  if docker exec "$container" sh -c 'command -v wget >/dev/null 2>&1'; then
    docker exec "$container" \
      wget \
      -q \
      -O /dev/null \
      --timeout=5 \
      "$url" \
      >/dev/null 2>&1
    return $?
  fi

  warn "neither curl nor wget exists inside $container"
  return 2
}

# ─────────────────────────────────────────────────────────────────────────────
# HTTP probe from EC2 host
# ─────────────────────────────────────────────────────────────────────────────
host_http_probe() {
  local url="$1"

  if command -v curl >/dev/null 2>&1; then
    curl \
      --fail \
      --silent \
      --show-error \
      --max-time 5 \
      "$url" \
      >/dev/null 2>&1
    return $?
  fi

  if command -v wget >/dev/null 2>&1; then
    wget \
      -q \
      -O /dev/null \
      --timeout=5 \
      "$url" \
      >/dev/null 2>&1
    return $?
  fi

  warn "neither curl nor wget exists on EC2 host"
  return 2
}

# ─────────────────────────────────────────────────────────────────────────────
# Nginx reload
# ─────────────────────────────────────────────────────────────────────────────
reload_nginx() {
  info "validating nginx configuration"

  if ! docker exec "$NGINX_CONTAINER" nginx -t >/dev/null 2>&1; then
    warn "nginx -t failed:"
    docker exec "$NGINX_CONTAINER" nginx -t 2>&1 |
      sed 's/^/    /' >&2 || true
    return 1
  fi

  info "reloading nginx"
  docker exec "$NGINX_CONTAINER" nginx -s reload
}

# ─────────────────────────────────────────────────────────────────────────────
# Write upstream atomically
#
# The file MUST be a map over the empty string, and the variable name MUST be
# $<upstream_name>_backend: the vhosts proxy through that variable, which is
# how nginx resolves the slot hostname at request time (Docker DNS, 10s
# cache) instead of at start-up. A static `upstream` block with an
# unresolvable slot name keeps the whole nginx edge from starting — the
# 2026-10-09 outage. max_fails/fail_timeout/keepalive are upstream-block
# directives and deliberately gone with it.
# ─────────────────────────────────────────────────────────────────────────────
write_upstream() {
  local slot="$1"
  local port
  local tmp

  port="$(slot_port "$slot")"

  tmp="$(mktemp "$UPSTREAM_DIR/.${UPSTREAM_NAME}.XXXXXX")"

  cat > "$tmp" <<EOF
# Generated by deploy.sh
# generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# app=$APP_NAME
# slot=$slot
# port=$port
# commit=$COMMIT_SHA
# vhost=$EDGE_HEALTH_HOST

map '' \$${UPSTREAM_NAME}_backend {
    default ${APP_NAME}-${slot}:${port};
}
EOF

  chmod 644 "$tmp"
  mv -f "$tmp" "$UPSTREAM_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
# Failure cleanup / rollback
# ─────────────────────────────────────────────────────────────────────────────
FLIPPED=false
UPSTREAM_BACKUP=""

cleanup_on_failure() {
  local rc=$?

  (( rc == 0 )) && return 0

  echo ""
  warn "deployment failed with exit code $rc"

  if [[ "$FLIPPED" == true &&
        -n "$UPSTREAM_BACKUP" &&
        -r "$UPSTREAM_BACKUP" ]]; then

    warn "restoring previous nginx upstream"

    cp "$UPSTREAM_BACKUP" "$UPSTREAM_FILE"

    if ! reload_nginx; then
      warn "CRITICAL: nginx rollback reload failed"
      warn "CHECK THE EDGE IMMEDIATELY"
    fi

    set_active_slot "$APP_NAME" "$ACTIVE"
  fi

  warn "tearing down candidate slot: $TARGET"

  compose_target down --remove-orphans \
    >/dev/null 2>&1 || true

  warn "live slot remains: $ACTIVE"

  exit "$rc"
}

trap cleanup_on_failure EXIT

# ─────────────────────────────────────────────────────────────────────────────
# 1. Pull immutable image
# ─────────────────────────────────────────────────────────────────────────────
info "pulling image"

docker pull --quiet "$IMAGE" >/dev/null || {
  die "could not pull image: $IMAGE"
}

ok "image present locally"

# ─────────────────────────────────────────────────────────────────────────────
# 2. Start target slot
# ─────────────────────────────────────────────────────────────────────────────
info "starting target slot: $TARGET"

compose_target down --remove-orphans \
  >/dev/null 2>&1 || true

compose_target up -d --no-build

ok "$TARGET_CONTAINER started"

# ─────────────────────────────────────────────────────────────────────────────
# 3. Docker HEALTHCHECK
# ─────────────────────────────────────────────────────────────────────────────
DOCKER_HEALTH_OK=false

if [[ "$CHECK_DOCKER_HEALTH" == true ]]; then
  info "waiting for Docker healthcheck: $TARGET_CONTAINER"

  if wait_for_health "$TARGET_CONTAINER" "$HEALTH_TIMEOUT"; then
    DOCKER_HEALTH_OK=true
    ok "Docker healthcheck passed"
  else
    warn "$TARGET_CONTAINER did not become healthy within ${HEALTH_TIMEOUT}s"
    warn "last 60 log lines from $TARGET_CONTAINER:"

    docker logs \
      --tail 60 \
      "$TARGET_CONTAINER" 2>&1 |
      sed 's/^/    /' >&2 || true

    if [[ "$CONTINUE_ON_HEALTH_FAILURE" == true ]]; then
      warn "Docker healthcheck failed — CONTINUING deployment"
    else
      die "candidate Docker healthcheck failed"
    fi
  fi
else
  warn "Docker healthcheck disabled"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 4. Candidate-container LOCAL healthcheck
# ─────────────────────────────────────────────────────────────────────────────
LOCAL_HEALTH_OK=false

if [[ "$CHECK_CONTAINER_LOCAL" == true ]]; then
  info "checking candidate locally from inside $TARGET_CONTAINER"

  LOCAL_URL="http://127.0.0.1:${TARGET_PORT}${CONTAINER_HEALTH_PATH}"

  if retry_command \
    "local health" \
    "$HEALTH_RETRIES" \
    "$HEALTH_RETRY_INTERVAL" \
    container_http_probe \
    "$TARGET_CONTAINER" \
    "$LOCAL_URL"; then

    LOCAL_HEALTH_OK=true
    ok "candidate local healthcheck passed"
  else
    warn "candidate local healthcheck failed"
    warn "URL: $LOCAL_URL"

    if [[ "$CONTINUE_ON_HEALTH_FAILURE" == true ]]; then
      warn "local healthcheck failed — CONTINUING deployment"
    else
      die "candidate local healthcheck failed"
    fi
  fi
else
  warn "candidate local healthcheck disabled"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. Candidate reachability from Nginx
# ─────────────────────────────────────────────────────────────────────────────
NGINX_NETWORK_OK=false

if [[ "$CHECK_NGINX_NETWORK" == true ]]; then
  info "checking candidate from nginx container"

  NGINX_TARGET_URL="http://${TARGET_CONTAINER}:${TARGET_PORT}${CONTAINER_HEALTH_PATH}"

  if retry_command \
    "nginx network probe" \
    "$HEALTH_RETRIES" \
    "$HEALTH_RETRY_INTERVAL" \
    container_http_probe \
    "$NGINX_CONTAINER" \
    "$NGINX_TARGET_URL"; then

    NGINX_NETWORK_OK=true
    ok "nginx can reach candidate"
  else
    warn "nginx could not reach candidate"
    warn "URL: $NGINX_TARGET_URL"

    if [[ "$CONTINUE_ON_HEALTH_FAILURE" == true ]]; then
      warn "nginx network healthcheck failed — CONTINUING deployment"
    else
      die "nginx cannot reach candidate"
    fi
  fi
else
  warn "nginx network healthcheck disabled"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 6. EC2 HOST healthcheck
# ─────────────────────────────────────────────────────────────────────────────
HOST_HEALTH_OK=false

info "checking candidate from EC2 host"

if retry_command \
  "EC2 host health" \
  "$HEALTH_RETRIES" \
  "$HEALTH_RETRY_INTERVAL" \
  host_http_probe \
  "$HOST_HEALTH_URL"; then

  HOST_HEALTH_OK=true
  ok "EC2 host healthcheck passed"
else
  warn "EC2 host healthcheck failed"
  warn "URL: $HOST_HEALTH_URL"

  if [[ "$CONTINUE_ON_HEALTH_FAILURE" == true ]]; then
    warn "EC2 host healthcheck failed — CONTINUING deployment"
  else
    die "EC2 host healthcheck failed"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Health summary
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "───────────────────────────────────────────────────────────────"
echo " Candidate health summary"
echo "───────────────────────────────────────────────────────────────"
echo " Target slot         : $TARGET"
echo " Target port         : $TARGET_PORT"
echo " Docker health       : $([ "$DOCKER_HEALTH_OK" = true ] && echo "PASS" || echo "FAIL/WARNING")"
echo " Container-local     : $([ "$LOCAL_HEALTH_OK" = true ] && echo "PASS" || echo "FAIL/WARNING")"
echo " Nginx network       : $([ "$NGINX_NETWORK_OK" = true ] && echo "PASS" || echo "FAIL/WARNING")"
echo " EC2 host            : $([ "$HOST_HEALTH_OK" = true ] && echo "PASS" || echo "FAIL/WARNING")"
echo " Continue on failure: $CONTINUE_ON_HEALTH_FAILURE"
echo "───────────────────────────────────────────────────────────────"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 7. Prepare Nginx flip
# ─────────────────────────────────────────────────────────────────────────────
info "preparing traffic flip to $TARGET"

if [[ -r "$UPSTREAM_FILE" ]]; then
  UPSTREAM_BACKUP="$(mktemp "$UPSTREAM_DIR/.${UPSTREAM_NAME}.backup.XXXXXX")"
  cp "$UPSTREAM_FILE" "$UPSTREAM_BACKUP"
else
  warn "no existing upstream file found"
  warn "rollback may not be possible if nginx reload fails"
fi

write_upstream "$TARGET"
FLIPPED=true

# ─────────────────────────────────────────────────────────────────────────────
# 8. Nginx validation + reload
#
# nginx -t is the guard that keeps a wrong-format slot file from ever going
# live: if the file does not define $<upstream_name>_backend, validation
# fails and the previous file is restored below.
# ─────────────────────────────────────────────────────────────────────────────
if ! reload_nginx; then
  die "nginx reload failed — previous upstream will be restored"
fi

set_active_slot "$APP_NAME" "$TARGET"

ok "traffic switched to $TARGET"

# ─────────────────────────────────────────────────────────────────────────────
# 9. Post-flip edge healthcheck
#
# Runs INSIDE the nginx container, sending the app's vhost as the Host
# header, so it exercises exactly the path a browser takes: vhost match ->
# map variable -> runtime DNS -> slot container /health. Options come before
# the URL: busybox wget treats anything after the first URL as another URL,
# so a trailing --header never took effect in the previous version of this
# check.
# ─────────────────────────────────────────────────────────────────────────────
EDGE_OK=false

info "verifying traffic through nginx"

EDGE_URL="http://127.0.0.1${EDGE_HEALTH_PATH}"

for attempt in $(seq 1 "$EDGE_RETRIES"); do
  if docker exec "$NGINX_CONTAINER" \
    wget \
    -q \
    -O /dev/null \
    --timeout=5 \
    --header="Host: ${EDGE_HEALTH_HOST}" \
    "$EDGE_URL" \
    2>/dev/null; then

    EDGE_OK=true
    ok "post-flip edge healthcheck passed"
    break
  fi

  log "   edge health attempt $attempt/$EDGE_RETRIES failed"

  if (( attempt < EDGE_RETRIES )); then
    sleep "$EDGE_RETRY_INTERVAL"
  fi
done

if [[ "$EDGE_OK" != true ]]; then
  warn "post-flip edge /health check failed"
  warn "This check is NON-FATAL."
  warn "Direct candidate URL:"
  warn "http://${TARGET_CONTAINER}:${TARGET_PORT}${CONTAINER_HEALTH_PATH}"
  warn "Candidate host URL:"
  warn "$HOST_HEALTH_URL"
  warn "Candidate logs:"

  docker logs \
    --tail 100 \
    "$TARGET_CONTAINER" 2>&1 |
    sed 's/^/    /' >&2 || true
fi

# ─────────────────────────────────────────────────────────────────────────────
# Traffic flip succeeded; disable rollback trap.
# ─────────────────────────────────────────────────────────────────────────────
trap - EXIT

# ─────────────────────────────────────────────────────────────────────────────
# 10. Stop old slot
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$KEEP_OLD" == true ]]; then
  info "--keep-old enabled"
  info "leaving $ACTIVE_CONTAINER running for rollback"

elif [[ "$(container_state "$ACTIVE_CONTAINER")" != "absent" ]]; then
  info "draining old slot: $ACTIVE"

  if (( DRAIN_SECONDS > 0 )); then
    sleep "$DRAIN_SECONDS"
  fi

  compose_slot "$ACTIVE" down --remove-orphans || {
    warn "could not cleanly stop $ACTIVE_CONTAINER"
    warn "the new slot is already live"
  }

  ok "old slot retired"
else
  info "old slot already absent"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 11. Preserve Docker layer cache
# ─────────────────────────────────────────────────────────────────────────────
info "retaining Docker image cache for faster future deployments"

# Intentionally do NOT run:
#
# docker image prune -f
#
# Keeping cached image layers allows future ECR pulls to reuse unchanged
# layers and reduces deployment time.

# ─────────────────────────────────────────────────────────────────────────────
# 12. Remove temporary upstream backup
# ─────────────────────────────────────────────────────────────────────────────
if [[ -n "$UPSTREAM_BACKUP" ]]; then
  rm -f "$UPSTREAM_BACKUP" || true
fi

# ─────────────────────────────────────────────────────────────────────────────
# 13. Final deployment status
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==============================================================="
echo " Deployment completed"
echo "==============================================================="
echo ""
echo "  App                 : $APP_NAME"
echo "  Environment         : $ASPNETCORE_ENVIRONMENT"
echo "  Vault mount         : $VAULT_KV_MOUNT"
echo "  Vault path          : $VAULT_SECRET_PATH"
echo "  Previous slot       : $ACTIVE"
echo "  Previous port       : $ACTIVE_PORT"
echo "  Active slot         : $TARGET"
echo "  Active port         : $TARGET_PORT"
echo "  Active container    : $TARGET_CONTAINER"
echo "  Vhost               : $EDGE_HEALTH_HOST"
echo "  Image               : $IMAGE"
echo "  Commit              : $COMMIT_SHA"
echo ""
echo "  Docker health       : $([ "$DOCKER_HEALTH_OK" = true ] && echo "PASS" || echo "FAIL/WARNING")"
echo "  Container local     : $([ "$LOCAL_HEALTH_OK" = true ] && echo "PASS" || echo "FAIL/WARNING")"
echo "  Nginx network       : $([ "$NGINX_NETWORK_OK" = true ] && echo "PASS" || echo "FAIL/WARNING")"
echo "  EC2 host            : $([ "$HOST_HEALTH_OK" = true ] && echo "PASS" || echo "FAIL/WARNING")"
echo "  Edge /health        : $([ "$EDGE_OK" = true ] && echo "PASS" || echo "FAIL/WARNING")"
echo ""
echo "  Health failures     : NON-FATAL"
echo "  Nginx/config errors : FATAL"
echo ""
echo "==============================================================="

if [[ "$DOCKER_HEALTH_OK" != true ||
      "$LOCAL_HEALTH_OK" != true ||
      "$NGINX_NETWORK_OK" != true ||
      "$HOST_HEALTH_OK" != true ||
      "$EDGE_OK" != true ]]; then

  warn "deployment completed with one or more health warnings"
else
  ok "all health checks passed"
fi

exit 0
