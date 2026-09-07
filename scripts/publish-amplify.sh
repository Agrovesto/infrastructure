#!/usr/bin/env bash
# Deploy an already built static frontend ZIP (index.html at ZIP root).
# Use a separate frontend publisher role or an authorized AWS SSO session,
# not the infrastructure GitHub role from a frontend/application repository.
set -Eeuo pipefail
app_id=${1:?Usage: publish-amplify.sh APP_ID BRANCH BUILD.zip}
branch=${2:?Usage: publish-amplify.sh APP_ID BRANCH BUILD.zip}
archive=${3:?Usage: publish-amplify.sh APP_ID BRANCH BUILD.zip}
[[ -f "$archive" ]] || { echo 'Build ZIP does not exist.' >&2; exit 1; }
umask 077
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
aws amplify create-deployment --app-id "$app_id" --branch-name "$branch" > "$tmp/deployment.json"
# The upload URL is a temporary credential: never echo or log it.
# curl config keeps the signed URL out of the process command line.
jq -r '.zipUploadUrl | "url = " + (@json)' "$tmp/deployment.json" > "$tmp/curl.conf"
curl --fail --silent --show-error --retry 3 --config "$tmp/curl.conf" --upload-file "$archive"
job_id=$(jq -er .jobId "$tmp/deployment.json")
aws amplify start-deployment --app-id "$app_id" --branch-name "$branch" --job-id "$job_id" > /dev/null
for _ in $(seq 1 120); do
  status=$(aws amplify get-job --app-id "$app_id" --branch-name "$branch" --job-id "$job_id" --query 'job.summary.status' --output text)
  case "$status" in
    SUCCEED) echo 'Amplify deployment succeeded.'; exit 0 ;;
    FAILED|CANCELLED) echo "Amplify deployment $status. Inspect the Amplify console." >&2; exit 1 ;;
  esac
  sleep 10
done
echo 'Timed out waiting for Amplify; inspect the job before retrying.' >&2
exit 1
