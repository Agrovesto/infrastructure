#!/usr/bin/env bash
set -Eeuo pipefail

# Idempotently creates the SonarQube groups required for GitHub team sync and
# grants the permission matrix agreed for Agrovesto. Run this with a dedicated
# SonarQube global-administrator token; do not reuse the CI analysis token.
#
#   read -rsp 'Sonar admin token: ' SONAR_ADMIN_TOKEN; export SONAR_ADMIN_TOKEN
#   SONAR_BASE_URL=http://127.0.0.1:9000 ./configure-sonarqube-team-permissions.sh
#   unset SONAR_ADMIN_TOKEN

: "${SONAR_ADMIN_TOKEN:?Set SONAR_ADMIN_TOKEN to a SonarQube global-administrator token}"
SONAR_BASE_URL="${SONAR_BASE_URL:-http://127.0.0.1:9000}"
SONAR_BASE_URL="${SONAR_BASE_URL%/}"

for command in curl jq; do
  command -v "$command" >/dev/null || {
    echo "ERROR: $command is required" >&2
    exit 1
  }
done

umask 077
curl_config=$(mktemp)
response_file=$(mktemp)
cleanup() {
  rm -f "$curl_config" "$response_file"
}
trap cleanup EXIT
printf 'header = "Authorization: Bearer %s"\n' "$SONAR_ADMIN_TOKEN" >"$curl_config"
unset SONAR_ADMIN_TOKEN

api_get() {
  local endpoint=$1
  shift
  local -a args=()
  local field
  for field in "$@"; do
    args+=(--data-urlencode "$field")
  done
  curl --config "$curl_config" --silent --show-error --fail-with-body \
    --get "${args[@]}" "${SONAR_BASE_URL}/${endpoint}"
}

api_post() {
  local endpoint=$1
  shift
  local -a args=()
  local field status
  for field in "$@"; do
    args+=(--data-urlencode "$field")
  done

  status=$(curl --config "$curl_config" --silent --show-error \
    --request POST "${args[@]}" --output "$response_file" \
    --write-out '%{http_code}' "${SONAR_BASE_URL}/${endpoint}")

  case "$status" in
    2??) return 0 ;;
    400)
      # Permission-add endpoints on some SonarQube releases report an already
      # present grant as HTTP 400 rather than treating it as a no-op.
      if grep -Eqi 'already|exist|granted|duplicate' "$response_file"; then
        return 0
      fi
      ;;
  esac

  echo "ERROR: POST ${endpoint} returned HTTP ${status}" >&2
  cat "$response_file" >&2
  return 1
}

# SonarQube names synchronized GitHub groups as Organization/Team display name.
readonly -a groups=(
  "Agrovesto/Backend"
  "Agrovesto/Frontend"
  "Agrovesto/Infrastructure"
  "Agrovesto/mobile"
  "Agrovesto/team-leads"
)

project_permissions() {
  case "$1" in
    "Agrovesto/Backend"|"Agrovesto/Frontend"|"Agrovesto/mobile")
      printf '%s\n' user codeviewer
      ;;
    "Agrovesto/team-leads")
      # Read plus issue/hotspot status management: SonarQube's closest
      # least-privilege equivalent to an Editor/read-write role.
      printf '%s\n' user codeviewer issueadmin securityhotspotadmin
      ;;
    "Agrovesto/Infrastructure")
      printf '%s\n' user codeviewer issueadmin securityhotspotadmin scan admin
      ;;
    *)
      echo "ERROR: no permission policy for $1" >&2
      return 1
      ;;
  esac
}

for attempt in $(seq 1 60); do
  if status_json=$(api_get api/system/status 2>/dev/null) &&
    jq -e '.status == "UP"' >/dev/null <<<"$status_json"; then
    break
  fi
  if [ "$attempt" -eq 60 ]; then
    echo "ERROR: SonarQube did not become ready at ${SONAR_BASE_URL}" >&2
    exit 1
  fi
  sleep 5
done

for group in "${groups[@]}"; do
  search=$(api_get api/user_groups/search "q=$group" "ps=100")
  if ! jq -e --arg name "$group" '.groups[] | select(.name == $name)' >/dev/null <<<"$search"; then
    api_post api/user_groups/create \
      "name=$group" \
      "description=Membership synchronized from GitHub team $group"
    echo "Created SonarQube group: $group"
  fi
done

# Infrastructure is deliberately a SonarQube system administrator. The other
# groups receive only project permissions through the policy below.
api_post api/permissions/add_group \
  "groupName=Agrovesto/Infrastructure" \
  "permission=admin"

# Make the same matrix the default for future projects.
readonly template_name="Agrovesto GitHub teams"
templates=$(api_get api/permissions/search_templates "q=$template_name")
template_id=$(jq -r --arg name "$template_name" \
  '.permissionTemplates[] | select(.name == $name) | .id' <<<"$templates" | head -n1)
if [ -z "$template_id" ]; then
  api_post api/permissions/create_template \
    "name=$template_name" \
    "description=Permissions synchronized from Agrovesto GitHub teams"
  templates=$(api_get api/permissions/search_templates "q=$template_name")
  template_id=$(jq -r --arg name "$template_name" \
    '.permissionTemplates[] | select(.name == $name) | .id' <<<"$templates" | head -n1)
fi
if [ -z "$template_id" ]; then
  echo "ERROR: could not resolve the SonarQube permission template" >&2
  exit 1
fi

for group in "${groups[@]}"; do
  while IFS= read -r permission; do
    api_post api/permissions/add_group_to_template \
      "templateId=$template_id" \
      "groupName=$group" \
      "permission=$permission"
  done < <(project_permissions "$group")
done
api_post api/permissions/set_default_template \
  "templateId=$template_id" \
  "qualifier=TRK"

# Preserve every project's other grants: add this matrix to existing projects
# instead of bulk-applying the template, which would replace their permissions.
page=1
while :; do
  projects=$(api_get api/projects/search "p=$page" "ps=100" "qualifiers=TRK")
  while IFS= read -r project_key; do
    [ -n "$project_key" ] || continue
    for group in "${groups[@]}"; do
      while IFS= read -r permission; do
        api_post api/permissions/add_group \
          "projectKey=$project_key" \
          "groupName=$group" \
          "permission=$permission"
      done < <(project_permissions "$group")
    done
  done < <(jq -r '.components[].key' <<<"$projects")

  total=$(jq -r '.paging.total' <<<"$projects")
  if (( page * 100 >= total )); then
    break
  fi
  ((page += 1))
done

cat <<'SUMMARY'
SonarQube GitHub team permissions configured:
  Agrovesto/Backend        Reader
  Agrovesto/Frontend       Reader
  Agrovesto/Infrastructure System and project Admin
  Agrovesto/mobile         Reader
  Agrovesto/team-leads     Read/write issues and security hotspots
SUMMARY
