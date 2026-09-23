#!/usr/bin/env bash
# =============================================================================
# scripts/aws-inventory-scan.sh
#
# Discovery scan of the Agrovesto AWS accounts: list everything that exists,
# work out which of it this repo already manages, and write the result INTO THE
# FOLDER OF THE ENVIRONMENT IT CAME FROM:
#
#   dev/discovery/         <- scan of the dev account   (profile agrovesto-dev)
#   prod/discovery/        <- scan of the prod account  (profile agrovesto-prod)
#   monitoring/discovery/  <- prod-account resources that belong to monitoring/
#   .discovery/            <- combined dev-vs-prod view (repo root, gitignored)
#
# WHY
#   The point is to find resources that were created by hand (console, CLI,
#   another tool) and are NOT in Terraform yet, so they can be imported into the
#   right stack instead of being re-created - re-creating an existing bucket,
#   RDS instance or ALB means destroying the live one.
#
# HOW "ALREADY MANAGED" IS DECIDED
#   Every stack here sets provider default_tags (dev/versions.tf,
#   prod/versions.tf, monitoring/versions.tf):
#       Project = agrovesto, Environment = <env>, ManagedBy = terraform
#   and monitoring/ additionally sets Stack = monitoring (monitoring/locals.tf).
#   So: ManagedBy=terraform  -> created by this repo        (managed = yes)
#       tagged but not that  -> created some other way      (managed = no)
#       resource cannot be tagged (Route53 records, ...)    (managed = unknown)
#   "unknown" rows are NOT treated as import candidates - they are listed
#   separately, because guessing would drown the report in DNS records the prod
#   stack already owns. Use --with-state to settle them against real state.
#
# USAGE
#   ./scripts/aws-inventory-scan.sh                      # both accounts, eu-west-1
#   ./scripts/aws-inventory-scan.sh --env dev            # dev account only
#   ./scripts/aws-inventory-scan.sh --all-regions        # every enabled region
#   ./scripts/aws-inventory-scan.sh --services ec2,s3    # only some services
#   ./scripts/aws-inventory-scan.sh --with-state         # also diff vs tf state
#   ./scripts/aws-inventory-scan.sh --no-imports         # skip import blocks
#   ./scripts/aws-inventory-scan.sh --help
#
# OUTPUT, per environment (example: dev/discovery/)
#   SUMMARY.md              the report - start here
#   inventory.tsv           every resource found, tab separated (script input)
#   inventory.csv           the same, quoted for Excel/Sheets
#   unmanaged.csv           confident import candidates only
#   imports/imports-<stack>.tf.txt
#                           ready-to-paste `import` blocks (Terraform >= 1.5).
#                           Written as .tf.txt ON PURPOSE: a real .tf file under
#                           dev/discovery/ is inside the dev root module, so
#                           every local `terraform plan` would try to import the
#                           world. Rename/copy what you want into <stack>/.
#   runs/<timestamp>/       raw JSON of every API call, meta.json, findings.tsv,
#                           permissions.log (calls that failed)
#
# READ ONLY
#   Only sts/route53/s3/ec2/rds/... describe-*, list-* and get-* calls are made.
#   Nothing is created, changed or deleted. Secret VALUES are never read:
#   Secrets Manager and SSM are listed by name only.
#
# GITIGNORED
#   Output holds account IDs, IP addresses and internal hostnames and this repo
#   is public, so discovery/ and .discovery/ are in .gitignore. To keep one
#   curated snapshot in git anyway:  git add -f dev/discovery/SUMMARY.md
# =============================================================================

set -uo pipefail
# Deliberately NOT `set -e`. Most of the calls below are expected to fail on a
# real account - a service nobody uses, a region that is not enabled, a read
# permission the scanning role does not have. Each failure is recorded in
# runs/<ts>/permissions.log and the scan carries on; aborting on the first one
# would hide every service after it.

# =============================================================================
# CONFIG - override with flags or environment variables
# =============================================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEV_PROFILE="${DEV_PROFILE:-agrovesto-dev}"
PROD_PROFILE="${PROD_PROFILE:-agrovesto-prod}"
PRIMARY_REGION="${PRIMARY_REGION:-eu-west-1}"
SCAN_ALL_REGIONS="${SCAN_ALL_REGIONS:-no}" # legacy name from the old scan script

ENVS="all"          # dev | prod | all
SERVICE_FILTER=""   # empty = everything, else comma separated group names
WITH_STATE=0        # 1 = also read `terraform show -json` per stack
GEN_IMPORTS=1       # 1 = write import blocks
KEEP_RAW=1          # 1 = keep the raw JSON of every API call
KEEP_RUNS=5         # how many runs/<timestamp>/ directories to keep
MAX_DETAIL_CALLS=400 # cap on per-resource calls (S3 buckets, KMS keys, ...)

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

# Global services are scanned once per account, not once per region.
GLOBAL_SCANNERS="s3 route53 iam cloudfront cur"
REGIONAL_SCANNERS="ec2 network rds acm ecs ecr elb efs amplify secretsmanager kms sns sqs lambda scheduler events logs cloudwatch autoscaling cloudmap ssm dynamodb elasticache opensearch apigateway stepfunctions ses governance"

# Where each environment's report goes, relative to the repo root.
DEV_DIR="dev"
PROD_DIR="prod"
MONITORING_DIR="monitoring"
COMBINED_DIR=".discovery"

# =============================================================================
# TERMINAL HELPERS
# =============================================================================

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RED=$'\033[0;31m'; C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[1;33m'
  C_BLUE=$'\033[0;34m'; C_MAGENTA=$'\033[0;35m'; C_CYAN=$'\033[0;36m'; C_NC=$'\033[0m'
else
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_MAGENTA=""; C_CYAN=""; C_NC=""
fi

# Progress always goes to stderr. That is not cosmetic: the old version of this
# script printed its progress to stdout and then captured stdout to get the
# output directory back, so the "directory" was 200 lines of log and every
# `cat "$DEV_SCAN/SUMMARY.md"` after it silently failed.
say()   { printf '%s\n' "$*" >&2; }
info()  { say "${C_CYAN}$*${C_NC}"; }
ok()    { say "  ${C_GREEN}✓${C_NC} $*"; }
note()  { say "  ${C_BLUE}·${C_NC} $*"; }
warn()  { say "  ${C_YELLOW}!${C_NC} $*"; }
bad()   { say "${C_RED}$*${C_NC}"; }
rule()  { say "${C_MAGENTA}────────────────────────────────────────────────────────────${C_NC}"; }
header() { say ""; say "${C_YELLOW}══ $* ══${C_NC}"; }

die() { bad "ERROR: $*"; exit 1; }

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

usage() {
  cat <<'USAGE'
aws-inventory-scan.sh - find AWS resources that are not in Terraform yet.

Usage: ./scripts/aws-inventory-scan.sh [options]

Options:
  --env <dev|prod|all>     Which account(s) to scan. Default: all.
  --dev-profile <name>     AWS CLI profile for the dev account.
                           Default: $DEV_PROFILE or agrovesto-dev.
  --prod-profile <name>    AWS CLI profile for the prod account.
                           Default: $PROD_PROFILE or agrovesto-prod.
  --region <region>        Primary region. Default: eu-west-1.
  --all-regions            Scan every region the account has enabled.
  --services <a,b,c>       Only these groups. Available:
                             global:   s3 route53 iam cloudfront cur
                             regional: ec2 network rds acm ecs ecr elb efs
                                       amplify secretsmanager kms sns sqs
                                       lambda scheduler events logs cloudwatch
                                       autoscaling cloudmap ssm dynamodb
                                       elasticache opensearch apigateway
                                       stepfunctions ses governance
  --with-state             Also read `terraform show -json` from each stack and
                           mark resources that are already in state, including
                           the untaggable ones (Route53 records etc).
                           Needs terraform on PATH and the stack initialised.
  --no-state               Never touch terraform (default).
  --no-imports             Do not write the import block files.
  --no-raw                 Do not keep the raw JSON responses.
  --keep-runs <n>          How many timestamped run directories to keep.
                           Default: 5.
  -h, --help               This text.

Writes to dev/discovery/, prod/discovery/, monitoring/discovery/ and
.discovery/ - see the header of this script for the file layout.
USAGE
}

# =============================================================================
# ARGUMENTS
# =============================================================================

while [ $# -gt 0 ]; do
  case "$1" in
    --env)          ENVS="${2:-}"; shift 2 ;;
    --dev-profile)  DEV_PROFILE="${2:-}"; shift 2 ;;
    --prod-profile) PROD_PROFILE="${2:-}"; shift 2 ;;
    --region)       PRIMARY_REGION="${2:-}"; shift 2 ;;
    --all-regions)  SCAN_ALL_REGIONS="yes"; shift ;;
    --services)     SERVICE_FILTER="${2:-}"; shift 2 ;;
    --with-state)   WITH_STATE=1; shift ;;
    --no-state)     WITH_STATE=0; shift ;;
    --no-imports)   GEN_IMPORTS=0; shift ;;
    --no-raw)       KEEP_RAW=0; shift ;;
    --keep-runs)    KEEP_RUNS="${2:-5}"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *)              usage >&2; die "unknown option: $1" ;;
  esac
done

case "$(lower "$ENVS")" in
  dev|prod|all) ENVS="$(lower "$ENVS")" ;;
  *) usage >&2; die "--env must be dev, prod or all (got: $ENVS)" ;;
esac

[ "$(lower "$SCAN_ALL_REGIONS")" = "yes" ] && SCAN_ALL_REGIONS="yes" || SCAN_ALL_REGIONS="no"

# =============================================================================
# PREFLIGHT
# =============================================================================

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required but not on PATH. $2"
}

require_cmd aws  "Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
require_cmd jq   "Install: brew install jq  /  apt-get install jq"
require_cmd awk  ""

AWS_CLI_VERSION="$(aws --version 2>&1 | head -1)"

# =============================================================================
# jq PRELUDE
#
# Every scanner query is prefixed with this. It papers over the fact that AWS
# cannot decide how to return tags: EC2/EFS/Secrets use Tags, RDS uses TagList,
# ECS/ECR/ELB/Amplify use lowercase tags, S3 uses TagSet, Lambda and CloudWatch
# Logs use a {key: value} map. tagpairs normalises all of them.
# =============================================================================

read -r -d '' JQ_PRELUDE <<'JQEOF' || true
def tagpairs:
  ([.Tags, .tags, .TagList, .TagSet] | map(select(. != null)) | (.[0] // [])) as $t
  | if ($t | type) == "object"
      then ($t | to_entries | map({Key: (.key | tostring), Value: (.value | tostring)}))
    elif ($t | type) == "array"
      then ($t | map({Key: ((.Key // .key // "") | tostring), Value: ((.Value // .value // "") | tostring)}))
    else [] end;
def clean: (tostring | gsub("[\t\n\r|]"; " "));
def tag(k): ([tagpairs[] | select(.Key == k) | .Value][0] // "" | clean);
def tagstr: ([tagpairs[] | "\(.Key)=\(.Value | gsub("[\t\n\r|]"; " "))"] | join(";") | clean);
def n(x): ((x // "") | clean);
# Null-safe string surgery. `.Foo.Bar | split("/")` errors out (and silently
# drops every row after it) when the field is absent - an instance with no
# profile, a target group attached to nothing, a task with no compatibilities.
# These swallow the null first.
def parts(sep): ((. // "") | tostring | split(sep));
def lastpart(sep): (parts(sep) | last);
def tailjoin(sep; cnt; joiner): (parts(sep) | .[-cnt:] | join(joiner));
def num(x): ((x // 0) | tonumber? // 0);
def head(nchars): ((. // "") | tostring | .[0:nchars]);
# Rows go to bash separated by 0x1F (unit separator), NOT by tabs. bash `read`
# treats tab as IFS whitespace, so it collapses runs of tabs and drops leading
# and trailing empty fields - an untagged resource (empty Name, empty Stack tag)
# arrived with its columns shifted a place or two to the left. 0x1F is not IFS
# whitespace, so every empty field survives. The gsub strips it from values.
def us: (map(tostring | gsub("[\u001f\t\n\r|]"; " ")) | join("\u001f"));
def managed: (if (tag("ManagedBy") | ascii_downcase) == "terraform" then "yes" else "no" end);
def attrib(default_env):
  if (tag("Stack") | ascii_downcase) == "monitoring" then "monitoring"
  else
    (tag("Environment") | ascii_downcase) as $e
    | if $e == "" then default_env
      elif ($e == "dev" or $e == "prod" or $e == "monitoring") then $e
      else default_env end
  end;
JQEOF

# =============================================================================
# PER-RUN STATE (set by scan_env before each account is scanned)
# =============================================================================

CUR_ENV=""        # dev | prod
CUR_PROFILE=""
CUR_ACCOUNT=""
CUR_STACK_DIR=""  # dev | prod (repo folder for this account)
CUR_DISCOVERY=""  # <stack>/discovery
CUR_RUN=""        # <stack>/discovery/runs/<ts>
CUR_RAW=""
CUR_TSV=""
CUR_PERM=""
CUR_FAIL=""
API_CALLS=0
API_FAILS=0
RAW_FILES=0
DETAIL_CALLS=0
ROWS=0

# =============================================================================
# CORE HELPERS
# =============================================================================

# aws_json <profile> <region|global> <service> <args...>
# Prints the JSON response. Returns 1 (and logs) if the call failed, so callers
# can skip a service the role cannot read instead of dying.
aws_json() {
  local profile="$1" region="$2" service="$3"
  shift 3
  local cmd=(aws "$service" "$@" --output json --cli-connect-timeout 10)
  [ -n "$profile" ] && cmd+=(--profile "$profile")
  [ "$region" != "global" ] && cmd+=(--region "$region")

  local out rc
  out="$("${cmd[@]}" 2>>"${CUR_PERM:-/dev/null}")"
  rc=$?

  # Counters live in a file, not a variable: aws_json nearly always runs inside
  # $( ... ), so `API_CALLS=$((API_CALLS + 1))` here increments a copy that dies
  # with the subshell. The first version of this script reported "6 API calls"
  # for a scan that made 90.
  if [ -n "${CUR_RUN:-}" ]; then
    printf '%s\t%s\t%s\t%s\texit=%s\n' \
      "$region" "$service" "$*" "$(now_utc)" "$rc" >> "$CUR_RUN/api-calls.tsv"
  fi

  if [ $rc -ne 0 ]; then
    if [ -n "${CUR_FAIL:-}" ]; then
      printf '%s\t%s\t%s\t%s %s\texit=%s\n' \
        "$(now_utc)" "$CUR_ENV" "$service" "$*" "--region $region" "$rc" >> "$CUR_FAIL"
    fi
    return 1
  fi

  if [ "$KEEP_RAW" = "1" ] && [ -n "${CUR_RAW:-}" ]; then
    # Uniqueness comes from the filesystem rather than a counter variable, for
    # the same subshell reason as the call log above: two calls to the same
    # operation (one per bucket, per key, per service...) must not overwrite
    # each other.
    local op base slug i
    op="${1:-call}"
    base="$(printf '%s--%s--%s' "$region" "$service" "$op" | tr -c 'A-Za-z0-9._-' '_')"
    slug="${base}.json"
    i=1
    while [ -e "$CUR_RAW/$slug" ]; do
      slug="${base}--${i}.json"
      i=$((i + 1))
    done
    printf '%s' "$out" > "$CUR_RAW/$slug"
  fi
  printf '%s' "$out"
}

# jqr <filter>  (reads JSON on stdin, prints TSV rows on stdout)
jqr() {
  jq -r --arg env "$CUR_ENV" "$JQ_PRELUDE $1" 2>>"${CUR_PERM:-/dev/null}"
}

# detail_budget - true while per-resource calls are still allowed
detail_budget() {
  [ "$DETAIL_CALLS" -lt "$MAX_DETAIL_CALLS" ] || return 1
  DETAIL_CALLS=$((DETAIL_CALLS + 1))
  return 0
}

# row <service> <kind> <region> <name> <id> <tf_type> <import_id> <managed> \
#     <stack> <status> <details>
# One resource, one line of inventory.tsv. Field order is the contract used by
# the awk reporting code further down - change both or neither.
row() {
  # Callers pass:      service kind region name id tf_type import_id managed stack status details
  # The file stores:   env account stack service kind region name id tf_type import_id managed status details
  # (stack moves to column 3 so `awk -F'\t' '$3 == "monitoring"'` reads naturally)
  if [ $# -ne 11 ]; then
    warn "row() called with $# fields instead of 11 (service=$1) - row skipped"
    return 0
  fi
  local clean=() f
  for f in "$@"; do
    f="${f//[$'\t\n\r\x1f']/ }"
    clean+=("$f")
  done
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$CUR_ENV" "$CUR_ACCOUNT" \
    "${clean[8]}" "${clean[0]}" "${clean[1]}" "${clean[2]}" "${clean[3]}" "${clean[4]}" \
    "${clean[5]}" "${clean[6]}" "${clean[7]}" "${clean[9]}" "${clean[10]}" >> "$CUR_TSV"
  ROWS=$((ROWS + 1))
}

INVENTORY_HEADER="env	account_id	stack	service	kind	region	name	id	terraform_type	import_id	managed	status	details"

# =============================================================================
# SCANNERS - GLOBAL SERVICES (once per account)
# =============================================================================

scan_s3() {
  local profile="$1" region="global" json b
  json="$(aws_json "$profile" "$region" s3api list-buckets)" || return 0

  local names
  names="$(printf '%s' "$json" | jqr '.Buckets[]? | [.Name, .CreationDate] | us')" || return 0

  while IFS=$'\x1f' read -r bucket created; do
    [ -n "$bucket" ] || continue

    local bregion="unknown" versioning="Disabled" encryption="none" public="unknown" lifecycle="no" tags=""
    if detail_budget; then
      b="$(aws_json "$profile" "$region" s3api get-bucket-location --bucket "$bucket")" || b=""
      [ -n "$b" ] && bregion="$(printf '%s' "$b" | jqr 'n(if .LocationConstraint == "" or .LocationConstraint == null then "us-east-1" else .LocationConstraint end)')"
      [ -z "$bregion" ] && bregion="us-east-1"

      b="$(aws_json "$profile" "$region" s3api get-bucket-versioning --bucket "$bucket")" || b=""
      [ -n "$b" ] && versioning="$(printf '%s' "$b" | jqr 'n(if .Status == null or .Status == "" then "Disabled" else .Status end)')"

      b="$(aws_json "$profile" "$region" s3api get-bucket-encryption --bucket "$bucket")" || b=""
      [ -n "$b" ] && encryption="$(printf '%s' "$b" | jqr 'n(.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm) // "none"')"
      [ -z "$encryption" ] && encryption="none"

      b="$(aws_json "$profile" "$region" s3api get-public-access-block --bucket "$bucket")" || b=""
      if [ -n "$b" ]; then
        public="$(printf '%s' "$b" | jqr '
          .PublicAccessBlockConfiguration as $c
          | if $c == null then "unknown"
            elif ($c.BlockPublicAcls and $c.BlockPublicPolicy and $c.IgnorePublicAcls and $c.RestrictPublicBucketPolicies) then "blocked"
            else "partially-blocked" end')"
      fi

      b="$(aws_json "$profile" "$region" s3api get-bucket-lifecycle-configuration --bucket "$bucket")" || b=""
      [ -n "$b" ] && lifecycle="$(printf '%s' "$b" | jqr 'if (.Rules | length) > 0 then "yes" else "no" end')"

      b="$(aws_json "$profile" "$region" s3api get-bucket-tagging --bucket "$bucket")" || b=""
      if [ -n "$b" ]; then
        tags="$(printf '%s' "$b" | jqr '.TagSet as $t | {Tags: $t} | tagstr')"
      fi
    fi

    # The old script did `aws ... && echo Yes || echo No`, which put the whole
    # JSON response *and* the word Yes into the same variable. Status here is a
    # single word so the CSV stays readable.
    local status="private"
    [ "$public" = "blocked" ] || status="public-access-not-blocked"

    row s3 bucket "$bregion" "$bucket" "$bucket" aws_s3_bucket "$bucket" \
      "$(managed_from_tags "$tags")" "$(stack_from_tags "$tags" "$bucket")" "$status" \
      "encryption=$encryption|versioning=$versioning|public_access=$public|lifecycle=$lifecycle|created=$created|tags=$tags"
  done <<< "$names"
}

scan_route53() {
  local profile="$1" region="global" json tsv
  json="$(aws_json "$profile" "$region" route53 list-hosted-zones)" || return 0

  tsv="$(printf '%s' "$json" | jqr '
    .HostedZones[]?
    | [ ((.Id // "") | sub("^/hostedzone/"; "")), n(.Name | tostring | rtrimstr(".")), (.ResourceRecordSetCount // 0 | tostring),
        (if .Config.PrivateZone then "private" else "public" end), n(.CallerReference) ] | us')" || return 0

  while IFS=$'\x1f' read -r zid zname count visibility caller; do
    [ -n "$zid" ] || continue

    local tags="" tj
    if detail_budget; then
      tj="$(aws_json "$profile" "$region" route53 list-tags-for-resource --resource-type hostedzone --resource-id "$zid")" || tj=""
      [ -n "$tj" ] && tags="$(printf '%s' "$tj" | jqr '{Tags: .ResourceTagSet.Tags} | tagstr')"
    fi

    row route53 hosted-zone "global" "$zname" "$zid" aws_route53_zone "$zid" \
      "$(managed_from_tags "$tags")" "$(stack_from_tags "$tags" "$zname")" "$visibility" \
      "record_count=$count|caller_reference=$caller|tags=$tags"

    # Records are not taggable, so "managed" stays unknown for them: the prod
    # stack owns the nomaos.com zone and every record in it, and calling them
    # all import candidates would bury the real findings.
    local rj
    rj="$(aws_json "$profile" "$region" route53 list-resource-record-sets --hosted-zone-id "$zid")" || rj=""
    [ -z "$rj" ] && continue

    local recs
    recs="$(printf '%s' "$rj" | jqr '
      .ResourceRecordSets[]?
      | [ n(.Name | tostring | rtrimstr(".")), n(.Type), (.TTL // "" | tostring),
          n(if .AliasTarget then .AliasTarget.DNSName
            elif .ResourceRecords then ([.ResourceRecords[].Value] | join(","))
            else "" end),
          n(if .AliasTarget then "alias" else "record" end) ] | us')" || recs=""

    while IFS=$'\x1f' read -r rname rtype rttl rvalue rkind; do
      [ -n "$rname" ] || continue
      row route53 record "global" "$rname" "$zid/${rname}/${rtype}" \
        aws_route53_record "${zid}_${rname}_${rtype}" \
        "unknown" "$(stack_from_tags "$tags" "$zname")" "$rtype" \
        "zone=$zname|ttl=$rttl|value=$rvalue|kind=$rkind"
    done <<< "$recs"
  done <<< "$tsv"
}

scan_iam() {
  local profile="$1" region="global" json tsv

  json="$(aws_json "$profile" "$region" iam list-roles)" || json=""
  if [ -n "$json" ]; then
    tsv="$(printf '%s' "$json" | jqr '
      .Roles[]?
      | select((.Path | startswith("/aws-service-role/")) | not)
      | select((.RoleName | startswith("AWSServiceRoleFor")) | not)
      | [ n(.RoleName), n(.Arn), n(.Path), n(.CreateDate), ((.MaxSessionDuration // 0) | tostring), managed, tag("Stack"), tagstr ]
      | us')" || tsv=""
    while IFS=$'\x1f' read -r name arn path created session mng stg tags; do
      [ -n "$name" ] || continue
      row iam role "global" "$name" "$arn" aws_iam_role "$name" \
        "$mng" "$(attrib_stack "$name" "$stg")" "active" \
        "path=$path|created=$created|max_session=$session|tags=$tags"
    done <<< "$tsv"
  fi

  json="$(aws_json "$profile" "$region" iam list-policies --scope Local)" || json=""
  if [ -n "$json" ]; then
    # list-policies does not return tags either - one list-policy-tags call each.
    tsv="$(printf '%s' "$json" | jqr '
      .Policies[]?
      | [ n(.PolicyName), n(.Arn), n(.Path), ((.AttachmentCount // 0) | tostring), n(.CreateDate) ]
      | us')" || tsv=""
    while IFS=$'\x1f' read -r name arn path attached created; do
      [ -n "$name" ] || continue
      local status="active" tags="" mng="unknown" tj
      [ "$attached" = "0" ] && status="unattached"
      if detail_budget; then
        tj="$(aws_json "$profile" "global" iam list-policy-tags --policy-arn "$arn")" || tj=""
        if [ -n "$tj" ]; then
          tags="$(printf '%s' "$tj" | jqr 'tagstr')"
          mng="$(printf '%s' "$tj" | jqr 'managed')"
        fi
      fi
      row iam policy "global" "$name" "$arn" aws_iam_policy "$arn" \
        "$mng" "$(attrib_stack "$name" "")" "$status" \
        "path=$path|attachments=$attached|created=$created|tags=$tags"
    done <<< "$tsv"
  fi

  json="$(aws_json "$profile" "$region" iam list-instance-profiles)" || json=""
  if [ -n "$json" ]; then
    tsv="$(printf '%s' "$json" | jqr '
      .InstanceProfiles[]?
      | [ n(.InstanceProfileName), n(.Arn), n([.Roles[]?.RoleName] | join(",")), n(.CreateDate) ] | us')" || tsv=""
    while IFS=$'\x1f' read -r name arn roles created; do
      [ -n "$name" ] || continue
      row iam instance-profile "global" "$name" "$arn" aws_iam_instance_profile "$name" \
        "unknown" "$(attrib_stack "$name" "")" "active" "roles=$roles|created=$created"
    done <<< "$tsv"
  fi

  json="$(aws_json "$profile" "$region" iam list-users)" || json=""
  if [ -n "$json" ]; then
    tsv="$(printf '%s' "$json" | jqr '
      .Users[]? | [ n(.UserName), n(.Arn), n(.CreateDate), n(.PasswordLastUsed) ] | us')" || tsv=""
    while IFS=$'\x1f' read -r name arn created pwlast; do
      [ -n "$name" ] || continue
      row iam user "global" "$name" "$arn" aws_iam_user "$name" \
        "unknown" "$(attrib_stack "$name" "")" "active" \
        "created=$created|password_last_used=${pwlast:-never}"
    done <<< "$tsv"
  fi

  json="$(aws_json "$profile" "$region" iam list-openid-connect-providers)" || json=""
  if [ -n "$json" ]; then
    tsv="$(printf '%s' "$json" | jqr '
      .OpenIDConnectProviderList[]? | [ n(.Arn) ] | us')" || tsv=""
    while IFS=$'\x1f' read -r arn; do
      [ -n "$arn" ] || continue
      row iam oidc-provider "global" "$(printf '%s' "$arn" | awk -F/ '{print $NF}')" "$arn" \
        aws_iam_openid_connect_provider "$arn" "unknown" "$CUR_ENV" "active" "-"
    done <<< "$tsv"
  fi
}

scan_cloudfront() {
  local profile="$1" json tsv
  json="$(aws_json "$profile" "us-east-1" cloudfront list-distributions)" || return 0
  tsv="$(printf '%s' "$json" | jqr '
    .DistributionList.Items[]?
    | [ n(.Id), n(.DomainName), n(.Status), n(.Comment), n(.PriceClass), n([.Origins.Items[]?.DomainName] | join(",")), managed, tag("Stack"), tagstr ]
    | us')" || return 0
  while IFS=$'\x1f' read -r id domain status comment price origins mng stg tags; do
    [ -n "$id" ] || continue
    row cloudfront distribution "global" "${comment:-$id}" "$id" aws_cloudfront_distribution "$id" \
      "$mng" "$(attrib_stack "$comment" "$stg")" "$status" \
      "domain=$domain|price_class=$price|origins=$origins|tags=$tags"
  done <<< "$tsv"
}

# CUR report definitions only exist in us-east-1 (monitoring/cost.tf).
scan_cur() {
  local profile="$1" json tsv
  json="$(aws_json "$profile" "us-east-1" cur describe-report-definitions)" || return 0
  tsv="$(printf '%s' "$json" | jqr '
    .ReportDefinitions[]?
    | [ n(.ReportName), n(.S3Bucket), n(.S3Region), n(.TimeUnit), n(.Format), n(.Compression) ] | us')" || return 0
  while IFS=$'\x1f' read -r name bucket rregion unit fmt comp; do
    [ -n "$name" ] || continue
    row cur report-definition "us-east-1" "$name" "$name" aws_cur_report_definition "$name" \
      "unknown" "$CUR_ENV" "active" \
      "s3_bucket=$bucket|s3_region=$rregion|time_unit=$unit|format=$fmt|compression=$comp"
  done <<< "$tsv"
}

# =============================================================================
# SCANNERS - REGIONAL SERVICES
# =============================================================================

# attrib_stack <name> <Stack-tag>
# Which stack folder a resource most likely belongs to. In the prod account the
# monitoring/ stack lives too, and it is the only one that sets Stack=monitoring
# (monitoring/locals.tf); its components are also all named after the tool
# (grafana, prometheus, loki, tempo, alloy, ...). Everything else falls back to
# the account being scanned. Attribution is a hint for the report - the import
# blocks are grouped by it, so worth a sanity check before pasting.
attrib_stack() {
  local name stg
  name="$(lower "${1-}")"
  stg="$(lower "${2-}")"
  if [ "$CUR_ENV" = "prod" ]; then
    [ "$stg" = "monitoring" ] && { printf 'monitoring'; return; }
    case "$name" in
      *monitoring*|*grafana*|*prometheus*|*alertmanager*|*loki*|*tempo*|*alloy*|*blackbox*|*pushgateway*)
        printf 'monitoring'; return ;;
    esac
  fi
  printf '%s' "$CUR_ENV"
}

# managed_from_tags <tagstr> / stack_from_tags <tagstr> <name>
# The bash twins of jq's managed/attrib(), for S3 and Route53 zones, whose tags
# come back from a second API call as a "Key=Value;Key=Value" string.
managed_from_tags() {
  case "$(lower "$1")" in
    *managedby=terraform*) printf 'yes' ;;
    *)                     printf 'no' ;;
  esac
}

stack_from_tags() {
  local tags name low
  tags="$(lower "${1-}")"
  name="$(lower "${2-}")"
  case "$tags" in *stack=monitoring*) printf 'monitoring'; return ;; esac
  if [ "$CUR_ENV" = "prod" ]; then
    case "$name" in
      *monitoring*|*grafana*|*prometheus*|*alertmanager*|*loki*|*tempo*|*alloy*|*blackbox*|*pushgateway*)
        printf 'monitoring'; return ;;
    esac
  fi
  case "$tags" in
    *environment=dev*)  printf 'dev'; return ;;
    *environment=prod*) printf 'prod'; return ;;
  esac
  printf '%s' "$CUR_ENV"
}

# rows_from <profile> <region|global> <jq-filter> <aws args...>
# Runs one AWS call and turns it into TSV rows. Empty output (and exit 0) on any
# failure, so a scanner can list five resource types and lose one of them
# without losing the other four.
rows_from() {
  local profile="$1" region="$2" filter="$3"
  shift 3
  local json
  json="$(aws_json "$profile" "$region" "$@")" || return 0
  printf '%s' "$json" | jqr "$filter" 2>/dev/null || return 0
}

# --- compute -----------------------------------------------------------------

scan_ec2() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r id type state priv pub name mng stg subnet vpc iprofile launch tags; do
    [ -n "$id" ] || continue
    row ec2 instance "$r" "${name:-$id}" "$id" aws_instance "$id" "$mng" "$(attrib_stack "$name" "$stg")" "$state" \
      "instance_type=$type|private_ip=$priv|public_ip=$pub|subnet=$subnet|vpc=$vpc|instance_profile=$iprofile|launched=$launch|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .Reservations[]?.Instances[]?
    | [ .InstanceId, n(.InstanceType), n(.State.Name), n(.PrivateIpAddress), n(.PublicIpAddress),
        tag("Name"), managed, tag("Stack"), n(.SubnetId), n(.VpcId),
        n(.IamInstanceProfile.Arn | lastpart("/")), n(.LaunchTime), tagstr ] | us' \
    ec2 describe-instances)

  while IFS=$'\x1f' read -r id vtype size state az enc inst mng stg tags; do
    [ -n "$id" ] || continue
    row ec2 volume "$r" "${id}" "$id" aws_ebs_volume "$id" "$mng" "$(attrib_stack "$stg" "$stg")" "$state" \
      "volume_type=$vtype|size_gb=$size|az=$az|encrypted=$enc|attached_to=$inst|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .Volumes[]?
    | [ .VolumeId, n(.VolumeType), (.Size // 0 | tostring), n(.State), n(.AvailabilityZone),
        (.Encrypted | tostring), n(.Attachments[0].InstanceId), managed, tag("Stack"), tagstr ] | us' \
    ec2 describe-volumes)

  while IFS=$'\x1f' read -r id created size state desc enc mng stg tags; do
    [ -n "$id" ] || continue
    row ec2 snapshot "$r" "${desc:-$id}" "$id" aws_ebs_snapshot "$id" "$mng" "$(attrib_stack "$stg" "$stg")" "$state" \
      "created=$created|size_gb=$size|encrypted=$enc|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .Snapshots[]?
    | [ .SnapshotId, n(.StartTime), (.VolumeSize // 0 | tostring), n(.State), n(.Description),
        (.Encrypted | tostring), managed, tag("Stack"), tagstr ] | us' \
    ec2 describe-snapshots --owner-ids self)

  while IFS=$'\x1f' read -r alloc pubip inst assoc domain mng stg tags; do
    [ -n "$alloc" ] || continue
    local status="associated"
    [ -z "$inst" ] && status="unassociated"
    row ec2 elastic-ip "$r" "$pubip" "$alloc" aws_eip "$alloc" "$mng" "$(attrib_stack "$stg" "$stg")" "$status" \
      "public_ip=$pubip|instance=$inst|association=$assoc|domain=$domain|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .Addresses[]?
    | [ .AllocationId, n(.PublicIp), n(.InstanceId), n(.AssociationId), n(.Domain),
        managed, tag("Stack"), tagstr ] | us' \
    ec2 describe-addresses)

  while IFS=$'\x1f' read -r id name created arch mng stg tags; do
    [ -n "$id" ] || continue
    row ec2 ami "$r" "${name:-$id}" "$id" aws_ami "$id" "$mng" "$(attrib_stack "$name" "$stg")" "available" \
      "created=$created|arch=$arch|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .Images[]?
    | [ .ImageId, n(.Name), n(.CreationDate), n(.Architecture), managed, tag("Stack"), tagstr ] | us' \
    ec2 describe-images --owners self)

  while IFS=$'\x1f' read -r id name created mng stg tags; do
    [ -n "$id" ] || continue
    row ec2 key-pair "$r" "$name" "$id" aws_key_pair "$name" "$mng" "$(attrib_stack "$name" "$stg")" "active" \
      "created=$created|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .KeyPairs[]?
    | [ n(.KeyPairId), n(.KeyName), n(.CreateTime), managed, tag("Stack"), tagstr ] | us' \
    ec2 describe-key-pairs)

  while IFS=$'\x1f' read -r id name latest default created mng stg tags; do
    [ -n "$id" ] || continue
    row ec2 launch-template "$r" "$name" "$id" aws_launch_template "$id" "$mng" "$(attrib_stack "$name" "$stg")" "active" \
      "latest_version=$latest|default_version=$default|created=$created|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .LaunchTemplates[]?
    | [ .LaunchTemplateId, n(.LaunchTemplateName), (.LatestVersionNumber | tostring),
        (.DefaultVersionNumber | tostring), n(.CreateTime), managed, tag("Stack"), tagstr ] | us' \
    ec2 describe-launch-templates)
}

# --- networking --------------------------------------------------------------

scan_network() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r id cidr isdefault mng stg name tags; do
    [ -n "$id" ] || continue
    row network vpc "$r" "${name:-$id}" "$id" aws_vpc "$id" "$mng" "$(attrib_stack "$name" "$stg")" \
      "$([ "$isdefault" = "true" ] && printf 'default' || printf 'active')" "cidr=$cidr|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .Vpcs[]?
    | [ .VpcId, n(.CidrBlock), (.IsDefault | tostring), managed, tag("Stack"), tag("Name"), tagstr ] | us' \
    ec2 describe-vpcs)

  while IFS=$'\x1f' read -r id cidr az vpc pubip mng stg name tags; do
    [ -n "$id" ] || continue
    row network subnet "$r" "${name:-$id}" "$id" aws_subnet "$id" "$mng" "$(attrib_stack "$name" "$stg")" "active" \
      "cidr=$cidr|az=$az|vpc=$vpc|public_ip_on_launch=$pubip|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .Subnets[]?
    | [ .SubnetId, n(.CidrBlock), n(.AvailabilityZone), n(.VpcId), (.MapPublicIpOnLaunch | tostring),
        managed, tag("Stack"), tag("Name"), tagstr ] | us' \
    ec2 describe-subnets)

  while IFS=$'\x1f' read -r id name vpc desc ingress egress worldopen mng stg tags; do
    [ -n "$id" ] || continue
    row network security-group "$r" "$name" "$id" aws_security_group "$id" "$mng" "$(attrib_stack "$name" "$stg")" "active" \
      "vpc=$vpc|description=$desc|ingress_rules=$ingress|egress_rules=$egress|open_to_world=$worldopen|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .SecurityGroups[]?
    | [ .GroupId, n(.GroupName), n(.VpcId), n(.Description),
        (.IpPermissions | length | tostring), (.IpPermissionsEgress | length | tostring),
        ([.IpPermissions[]?
          | select((.IpRanges // [] | map(.CidrIp) | index("0.0.0.0/0"))
                or (.Ipv6Ranges // [] | map(.CidrIpv6) | index("::/0")))
          | "\(.FromPort // "all")-\(.ToPort // "all")/\(.IpProtocol)" ] | join(",")),
        managed, tag("Stack"), tagstr ] | us' \
    ec2 describe-security-groups)

  while IFS=$'\x1f' read -r id vpc main assoc routes mng stg name tags; do
    [ -n "$id" ] || continue
    row network route-table "$r" "${name:-$id}" "$id" aws_route_table "$id" "$mng" "$(attrib_stack "$name" "$stg")" \
      "$([ "$main" = "true" ] && printf 'main' || printf 'active')" \
      "vpc=$vpc|associations=$assoc|routes=$routes|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .RouteTables[]?
    | [ .RouteTableId, n(.VpcId),
        ([.Associations[]? | select(.Main)] | length > 0 | tostring),
        (.Associations | length | tostring), (.Routes | length | tostring),
        managed, tag("Stack"), tag("Name"), tagstr ] | us' \
    ec2 describe-route-tables)

  while IFS=$'\x1f' read -r id vpcs mng stg tags; do
    [ -n "$id" ] || continue
    row network internet-gateway "$r" "$id" "$id" aws_internet_gateway "$id" "$mng" "$(attrib_stack "$stg" "$stg")" "active" \
      "vpcs=$vpcs|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .InternetGateways[]?
    | [ .InternetGatewayId, n([.Attachments[]?.VpcId] | join(",")), managed, tag("Stack"), tagstr ] | us' \
    ec2 describe-internet-gateways)

  while IFS=$'\x1f' read -r id state subnet pubip vpc mng stg name tags; do
    [ -n "$id" ] || continue
    row network nat-gateway "$r" "${name:-$id}" "$id" aws_nat_gateway "$id" "$mng" "$(attrib_stack "$name" "$stg")" "$state" \
      "subnet=$subnet|public_ip=$pubip|vpc=$vpc|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .NatGateways[]?
    | [ .NatGatewayId, n(.State), n(.SubnetId), n(.NatGatewayAddresses[0].PublicIp), n(.VpcId),
        managed, tag("Stack"), tag("Name"), tagstr ] | us' \
    ec2 describe-nat-gateways)

  while IFS=$'\x1f' read -r id vpc isdefault entries mng stg tags; do
    [ -n "$id" ] || continue
    row network network-acl "$r" "$id" "$id" aws_network_acl "$id" "$mng" "$(attrib_stack "$stg" "$stg")" \
      "$([ "$isdefault" = "true" ] && printf 'default' || printf 'active')" "vpc=$vpc|rules=$entries|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .NetworkAcls[]?
    | [ .NetworkAclId, n(.VpcId), (.IsDefault | tostring), (.Entries | length | tostring),
        managed, tag("Stack"), tagstr ] | us' \
    ec2 describe-network-acls)

  while IFS=$'\x1f' read -r id resource status dest; do
    [ -n "$id" ] || continue
    local tags="" mng="unknown" tj
    if detail_budget; then
      tj="$(aws_json "$p" "$r" ec2 describe-tags --filters "Name=resource-id,Values=$id")" || tj=""
      if [ -n "$tj" ]; then
        tags="$(printf '%s' "$tj" | jqr '{Tags: .Tags} | tagstr')"
        mng="$(printf '%s' "$tj" | jqr '{Tags: .Tags} | managed')"
      fi
    fi
    row network flow-log "$r" "$resource" "$id" aws_flow_log "$id" "$mng" "$(attrib_stack "$resource" "")" "$status" \
      "resource=$resource|destination=$dest|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .FlowLogs[]?
    | [ .FlowLogId, n(.ResourceId), n(.FlowLogStatus), n(.LogDestination) ] | us' \
    ec2 describe-flow-logs)

  while IFS=$'\x1f' read -r id epsvc eptype vpc state mng stg tags; do
    [ -n "$id" ] || continue
    row network vpc-endpoint "$r" "$epsvc" "$id" aws_vpc_endpoint "$id" "$mng" "$(attrib_stack "$stg" "$stg")" "$state" \
      "service=$epsvc|type=$eptype|vpc=$vpc|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .VpcEndpoints[]?
    | [ .VpcEndpointId, n(.ServiceName), n(.VpcEndpointType), n(.VpcId), n(.State),
        managed, tag("Stack"), tagstr ] | us' \
    ec2 describe-vpc-endpoints)
}

# --- databases ---------------------------------------------------------------

scan_rds() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r id class engine version status multiaz enc storage endpoint dbname mng stg tags; do
    [ -n "$id" ] || continue
    row rds db-instance "$r" "$id" "$id" aws_db_instance "$id" "$mng" "$(attrib_stack "$id" "$stg")" "$status" \
      "class=$class|engine=$engine-$version|multi_az=$multiaz|encrypted=$enc|storage_gb=$storage|endpoint=$endpoint|database=$dbname|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .DBInstances[]?
    | [ .DBInstanceIdentifier, n(.DBInstanceClass), n(.Engine), n(.EngineVersion), n(.DBInstanceStatus),
        (.MultiAZ | tostring), (.StorageEncrypted | tostring), (.AllocatedStorage // 0 | tostring),
        n(.Endpoint.Address), n(.DBName), managed, tag("Stack"), tagstr ] | us' \
    rds describe-db-instances)

  while IFS=$'\x1f' read -r id engine status endpoint members mng stg tags; do
    [ -n "$id" ] || continue
    row rds db-cluster "$r" "$id" "$id" aws_rds_cluster "$id" "$mng" "$(attrib_stack "$id" "$stg")" "$status" \
      "engine=$engine|endpoint=$endpoint|members=$members|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .DBClusters[]?
    | [ .DBClusterIdentifier, n(.Engine), n(.Status), n(.Endpoint),
        n([.DBClusterMembers[]?.DBInstanceIdentifier] | join(",")), managed, tag("Stack"), tagstr ] | us' \
    rds describe-db-clusters)

  while IFS=$'\x1f' read -r name vpc status subnets mng stg tags; do
    [ -n "$name" ] || continue
    row rds db-subnet-group "$r" "$name" "$name" aws_db_subnet_group "$name" "$mng" "$(attrib_stack "$name" "$stg")" "$status" \
      "vpc=$vpc|subnets=$subnets|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .DBSubnetGroups[]?
    | select(.DBSubnetGroupName != "default")
    | [ .DBSubnetGroupName, n(.VpcId), n(.SubnetGroupStatus), n([.Subnets[]?.SubnetIdentifier] | join(",")),
        managed, tag("Stack"), tagstr ] | us' \
    rds describe-db-subnet-groups)

  while IFS=$'\x1f' read -r id source created size status stype mng stg tags; do
    [ -n "$id" ] || continue
    row rds db-snapshot "$r" "$id" "$id" aws_db_snapshot "$id" "$mng" "$(attrib_stack "$stg" "$stg")" "$status" \
      "source=$source|created=$created|size_gb=$size|type=$stype|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .DBSnapshots[]?
    | [ .DBSnapshotIdentifier, n(.DBInstanceIdentifier), n(.SnapshotCreateTime), (.AllocatedStorage // 0 | tostring),
        n(.Status), n(.SnapshotType), managed, tag("Stack"), tagstr ] | us' \
    rds describe-db-snapshots --snapshot-type manual)

  while IFS=$'\x1f' read -r name family desc mng stg tags; do
    [ -n "$name" ] || continue
    row rds db-parameter-group "$r" "$name" "$name" aws_db_parameter_group "$name" "$mng" "$(attrib_stack "$name" "$stg")" "active" \
      "family=$family|description=$desc|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .DBParameterGroups[]?
    | select((.DBParameterGroupName | startswith("default.")) | not)
    | [ .DBParameterGroupName, n(.DBParameterGroupFamily), n(.Description), managed, tag("Stack"), tagstr ] | us' \
    rds describe-db-parameter-groups)
}

# --- containers / images -----------------------------------------------------

scan_ecs() {
  local p="$1" r="$2" arn name

  local clusters
  clusters="$(rows_from "$p" "$r" '.clusterArns[]?' ecs list-clusters)"
  while IFS= read -r arn; do
    [ -n "$arn" ] || continue
    while IFS=$'\x1f' read -r cname cstatus services tasks running capacity mng stg tags; do
      [ -n "$cname" ] || continue
      row ecs cluster "$r" "$cname" "$arn" aws_ecs_cluster "$cname" "$mng" "$(attrib_stack "$cname" "$stg")" "$cstatus" \
        "services=$services|task_definitions=$tasks|running=$running|registered_capacity=$capacity|tags=$tags"
    done < <(rows_from "$p" "$r" '
      .clusters[]?
      | [ n(.clusterName), n(.status), (.registeredContainerInstancesCount // 0 | tostring),
          (.runningTasksCount // 0 | tostring), (.pendingTasksCount // 0 | tostring),
          (.runningTasksCount // 0 | tostring), managed, tag("Stack"), tagstr ] | us' \
      ecs describe-clusters --clusters "$arn" --include TAGS)

    local svc_arns
    svc_arns="$(rows_from "$p" "$r" '.serviceArns[]?' ecs list-services --cluster "$arn")"
    while IFS= read -r svc_arn; do
      [ -n "$svc_arn" ] || continue
      while IFS=$'\x1f' read -r sname sstatus desired running taskdef launch cap mng stg tags; do
        [ -n "$sname" ] || continue
        row ecs service "$r" "$sname" "$svc" aws_ecs_service "${arn##*/}/${sname}" "$mng" \
          "$(attrib_stack "$sname" "$stg")" "$sstatus" \
          "cluster=${arn##*/}|desired=$desired|running=$running|task_definition=$taskdef|launch_type=$launch|capacity_provider=$cap|tags=$tags"
      done < <(rows_from "$p" "$r" '
        .services[]?
        | [ n(.serviceName), n(.status), (.desiredCount // 0 | tostring), (.runningCount // 0 | tostring),
            n(.taskDefinition | tailjoin("/"; 2; ":")), n(.launchType),
            n(.capacityProviderStrategy[0].capacityProvider), managed, tag("Stack"), tagstr ] | us' \
        ecs describe-services --cluster "$arn" --services "$svc_arn" --include TAGS)
    done <<< "$svc_arns"
  done <<< "$clusters"

  # Task definitions: only the latest ACTIVE revision per family, otherwise a
  # busy cluster dumps hundreds of rows of history nobody is going to import.
  local families
  families="$(rows_from "$p" "$r" '.families[]?' ecs list-task-definition-families --status ACTIVE)"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    while IFS=$'\x1f' read -r fam rev status cpu mem runtime mng stg tags; do
      [ -n "$fam" ] || continue
      row ecs task-definition "$r" "${fam}:${rev}" "${fam}:${rev}" aws_ecs_task_definition "${fam}:${rev}" \
        "$mng" "$(attrib_stack "$fam" "$stg")" "$status" \
        "cpu=$cpu|memory=$mem|runtime=$runtime|tags=$tags"
    done < <(rows_from "$p" "$r" '
      .taskDefinition as $t
      | [ n($t.family), ($t.revision // 0 | tostring), n($t.status), n($t.cpu), n($t.memory),
          n(($t.requiresCompatibilities // []) | join(",")), managed, tag("Stack"), tagstr ] | us' \
      ecs describe-task-definition --task-definition "$name" --include TAGS)
  done <<< "$families"
}

scan_ecr() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r name uri mutability scanning created mng stg tags; do
    [ -n "$name" ] || continue
    # One extra call per repo: both stacks attach an aws_ecr_lifecycle_policy
    # (dev/ecr.tf, prod/ecr.tf), so a repo without one is worth flagging.
    local lifecycle="no"
    if detail_budget; then
      aws_json "$p" "$r" ecr get-lifecycle-policy --repository-name "$name" >/dev/null 2>&1 && lifecycle="yes"
    fi
    row ecr repository "$r" "$name" "$uri" aws_ecr_repository "$name" "$mng" "$(attrib_stack "$name" "$stg")" "active" \
      "uri=$uri|tag_mutability=$mutability|scan_on_push=$scanning|lifecycle_policy=$lifecycle|created=$created|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .repositories[]?
    | [ n(.repositoryName), n(.repositoryUri), n(.imageTagMutability),
        n(.imageScanningConfiguration.scanOnPush | tostring), n(.createdAt),
        managed, tag("Stack"), tagstr ] | us' \
    ecr describe-repositories)
}

scan_elb() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r arn name type scheme state dns vpc zones mng stg tags; do
    [ -n "$arn" ] || continue
    row elb load-balancer "$r" "$name" "$arn" aws_lb "$arn" "$mng" "$(attrib_stack "$name" "$stg")" "$state" \
      "type=$type|scheme=$scheme|dns_name=$dns|vpc=$vpc|zones=$zones|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .LoadBalancers[]?
    | [ .LoadBalancerArn, n(.LoadBalancerName), n(.Type), n(.Scheme), n(.State.Code), n(.DNSName),
        n(.VpcId), n([.AvailabilityZones[]?.ZoneName] | join(",")), managed, tag("Stack"), tagstr ] | us' \
    elbv2 describe-load-balancers)

  while IFS=$'\x1f' read -r arn name port proto ttype lb mng stg tags; do
    [ -n "$arn" ] || continue
    row elb target-group "$r" "$name" "$arn" aws_lb_target_group "$arn" "$mng" "$(attrib_stack "$name" "$stg")" "active" \
      "port=$port|protocol=$proto|target_type=$ttype|load_balancer=$lb|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .TargetGroups[]?
    | [ .TargetGroupArn, n(.TargetGroupName), ((.TargetGroupPort // .Port // "") | tostring), n(.Protocol),
        n(.TargetType), n(.LoadBalancerArns[0] | tailjoin("/"; 2; "/")),
        managed, tag("Stack"), tagstr ] | us' \
    elbv2 describe-target-groups)

  local lbs
  lbs="$(rows_from "$p" "$r" '.LoadBalancers[]? | [.LoadBalancerArn, .LoadBalancerName] | us' elbv2 describe-load-balancers)"
  while IFS=$'\x1f' read -r lb_arn lb_name; do
    [ -n "$lb_arn" ] || continue
    while IFS=$'\x1f' read -r arn port proto default_tg; do
      [ -n "$arn" ] || continue
      row elb listener "$r" "${lb_name}:${port}" "$arn" aws_lb_listener "$arn" "unknown" \
        "$(attrib_stack "$lb_name" "")" "active" \
        "load_balancer=$lb_name|port=$port|protocol=$proto|default_target_group=$default_tg"
    done < <(rows_from "$p" "$r" '
      .Listeners[]?
      | [ .ListenerArn, (.Port | tostring), n(.Protocol),
          n(.DefaultActions[0].TargetGroupArn | lastpart("/")) ] | us' \
      elbv2 describe-listeners --load-balancer-arn "$lb_arn")
  done <<< "$lbs"

  while IFS=$'\x1f' read -r name dns state instances; do
    [ -n "$name" ] || continue
    row elb classic-lb "$r" "$name" "$name" aws_elb "$name" "unknown" "$(attrib_stack "$name" "")" "$state" \
      "dns_name=$dns|instances=$instances"
  done < <(rows_from "$p" "$r" '
    .LoadBalancerDescriptions[]?
    | [ n(.LoadBalancerName), n(.DNSName), n(.Scheme), n([.Instances[]?.InstanceId] | join(",")) ] | us' \
    elb describe-load-balancers)
}

# --- storage -----------------------------------------------------------------

scan_efs() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r id name state perf thru enc sizegb mng stg tags; do
    [ -n "$id" ] || continue
    row efs file-system "$r" "${name:-$id}" "$id" aws_efs_file_system "$id" "$mng" "$(attrib_stack "$name" "$stg")" "$state" \
      "performance_mode=$perf|throughput_mode=$thru|encrypted=$enc|size_gb=$sizegb|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .FileSystems[]?
    | [ .FileSystemId, tag("Name"), n(.LifeCycleState), n(.PerformanceMode), n(.ThroughputMode),
        (.Encrypted | tostring), (num(.SizeInBytes.Value) / 1073741824 | floor | tostring),
        managed, tag("Stack"), tagstr ] | us' \
    efs describe-file-systems)

  while IFS=$'\x1f' read -r id fs subnet az state mng stg tags; do
    [ -n "$id" ] || continue
    row efs mount-target "$r" "$fs" "$id" aws_efs_mount_target "$id" "$mng" "$(attrib_stack "$stg" "$stg")" "$state" \
      "file_system=$fs|subnet=$subnet|az=$az|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .MountTargets[]?
    | [ .MountTargetId, n(.FileSystemId), n(.SubnetId), n(.AvailabilityZoneName), n(.LifeCycleState),
        managed, tag("Stack"), tagstr ] | us' \
    efs describe-mount-targets)

  while IFS=$'\x1f' read -r id fs name posix mng stg tags; do
    [ -n "$id" ] || continue
    row efs access-point "$r" "${name:-$id}" "$id" aws_efs_access_point "$id" "$mng" "$(attrib_stack "$name" "$stg")" "active" \
      "file_system=$fs|root_path=$posix|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .AccessPoints[]?
    | [ .AccessPointId, n(.FileSystemId), tag("Name"), n(.RootDirectory.Path), managed, tag("Stack"), tagstr ] | us' \
    efs describe-access-points)
}

# --- app hosting / edge ------------------------------------------------------

scan_amplify() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r id name repo branch platform domain created mng stg tags; do
    [ -n "$id" ] || continue
    row amplify app "$r" "$name" "$id" aws_amplify_app "$id" "$mng" "$(attrib_stack "$name" "$stg")" "active" \
      "repository=$repo|branch=$branch|platform=$platform|default_domain=$domain|created=$created|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .apps[]?
    | [ n(.appId), n(.name), n(.repository), n(.branch), n(.platform), n(.defaultDomain), n(.createTime),
        managed, tag("Stack"), (.tags // {} | to_entries | map("\(.key)=\(.value)") | join(";") | clean) ] | us' \
    amplify list-apps)

  local apps
  apps="$(rows_from "$p" "$r" '.apps[]? | [.appId, .name] | us' amplify list-apps)"
  while IFS=$'\x1f' read -r app_id app_name; do
    [ -n "$app_id" ] || continue
    while IFS=$'\x1f' read -r bname stage; do
      [ -n "$bname" ] || continue
      row amplify branch "$r" "${app_name}/${bname}" "$app_id/$bname" aws_amplify_branch "$app_id/$bname" \
        "unknown" "$(attrib_stack "$app_name" "")" "$stage" "app=$app_name|branch=$bname"
    done < <(rows_from "$p" "$r" '
      .branches[]? | [ n(.branchName), n(.stage) ] | us' \
      amplify list-branches --app-id "$app_id")
  done <<< "$apps"
}

scan_apigateway() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r id name created mng stg tags; do
    [ -n "$id" ] || continue
    row apigateway rest-api "$r" "${name:-$id}" "$id" aws_api_gateway_rest_api "$id" "$mng" \
      "$(attrib_stack "$name" "$stg")" "active" "created=$created|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .items[]?
    | [ n(.id), n(.name), n(.createdDate), managed, tag("Stack"), tagstr ] | us' \
    apigateway get-rest-apis)

  while IFS=$'\x1f' read -r id name proto endpoint mng stg tags; do
    [ -n "$id" ] || continue
    row apigateway http-api "$r" "${name:-$id}" "$id" aws_apigatewayv2_api "$id" "$mng" \
      "$(attrib_stack "$name" "$stg")" "active" "protocol=$proto|endpoint=$endpoint|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .Items[]?
    | [ n(.ApiId), n(.Name), n(.ProtocolType), n(.ApiEndpoint), managed, tag("Stack"), tagstr ] | us' \
    apigatewayv2 get-apis)
}

scan_stepfunctions() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r arn name created mng stg tags; do
    [ -n "$arn" ] || continue
    row stepfunctions state-machine "$r" "$name" "$arn" aws_sfn_state_machine "$arn" "$mng" \
      "$(attrib_stack "$name" "$stg")" "active" "created=$created|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .stateMachines[]?
    | [ n(.stateMachineArn), n(.name), n(.creationDate), managed, tag("Stack"), tagstr ] | us' \
    stepfunctions list-state-machines)
}

# --- certificates ------------------------------------------------------------

scan_acm() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r arn domain status type imported created; do
    [ -n "$arn" ] || continue
    local tags="" mng="unknown"
    if detail_budget; then
      local tj
      tj="$(aws_json "$p" "$r" acm list-tags-for-certificate --certificate-arn "$arn")" || tj=""
      if [ -n "$tj" ]; then
        tags="$(printf '%s' "$tj" | jqr '{Tags: .Tags} | tagstr')"
        mng="$(printf '%s' "$tj" | jqr '{Tags: .Tags} | managed')"
      fi
    fi
    row acm certificate "$r" "$domain" "$arn" aws_acm_certificate "$arn" "$mng" \
      "$(attrib_stack "$domain" "")" "$status" \
      "domain=$domain|type=$type|imported=$imported|created=$created|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .CertificateSummaryList[]?
    | [ n(.CertificateArn), n(.DomainName), n(.Status), n(.Type), n(.ImportedAt), n(.CreatedAt) ] | us' \
    acm list-certificates)
}

# --- secrets / keys ----------------------------------------------------------

scan_secretsmanager() {
  local p="$1" r="$2"

  # Values are never read: list-secrets returns names, metadata and tags only.
  while IFS=$'\x1f' read -r name arn desc kms changed owning mng stg tags; do
    [ -n "$name" ] || continue
    row secretsmanager secret "$r" "$name" "$arn" aws_secretsmanager_secret "$arn" "$mng" \
      "$(attrib_stack "$name" "$stg")" "$([ -n "$owning" ] && printf 'owned-by-%s' "$owning" || printf 'active')" \
      "description=$desc|kms_key=${kms:-aws/secretsmanager (default)}|changed=$changed|owning_service=$owning|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .SecretList[]?
    | [ n(.Name), n(.ARN), n(.Description), n(.KmsKeyId), n(.LastChangedDate), n(.OwningService),
        managed, tag("Stack"), tagstr ] | us' \
    secretsmanager list-secrets)
}

scan_kms() {
  local p="$1" r="$2"

  # AWS managed keys (aws/s3, aws/ebs, ...) cannot be imported or deleted, so
  # they are skipped: describing every one of them is a call each for nothing.
  local keys
  keys="$(rows_from "$p" "$r" '.Keys[]?.KeyId' kms list-keys)"
  while IFS= read -r key; do
    [ -n "$key" ] || continue
    detail_budget || break
    while IFS=$'\x1f' read -r kid manager state desc created; do
      [ -n "$kid" ] || continue
      # aws/s3, aws/ebs, aws/ecr ... are AWS managed: not importable, not
      # deletable and not interesting. Only customer keys are reported.
      [ "$manager" = "AWS" ] && continue
      local tags="" mng="unknown" tj
      tj="$(aws_json "$p" "$r" kms list-resource-tags --key-id "$kid")" || tj=""
      if [ -n "$tj" ]; then
        tags="$(printf '%s' "$tj" | jqr 'tagstr')"
        mng="$(printf '%s' "$tj" | jqr 'managed')"
      fi
      row kms key "$r" "${desc:-$kid}" "$kid" aws_kms_key "$kid" "$mng" "$(attrib_stack "$desc" "")" "$state" \
        "manager=$manager|description=$desc|created=$created|arn=arn:aws:kms:${r}:${CUR_ACCOUNT}:key/${kid}|tags=$tags"
    done < <(rows_from "$p" "$r" '
      .KeyMetadata
      | [ n(.KeyId), n(.KeyManager), n(.KeyState), n(.Description), n(.CreationDate) ] | us' \
      kms describe-key --key-id "$key")
  done <<< "$keys"

  while IFS=$'\x1f' read -r alias target manager; do
    [ -n "$alias" ] || continue
    case "$alias" in alias/aws/*) continue ;; esac
    row kms alias "$r" "$alias" "$alias" aws_kms_alias "$alias" "unknown" \
      "$(attrib_stack "$alias" "")" "$([ -n "$target" ] && printf 'active' || printf 'dangling')" \
      "target_key=$target"
  done < <(rows_from "$p" "$r" '
    .Aliases[]? | [ n(.AliasName), n(.TargetKeyId), n(.KeyManager) ] | us' \
    kms list-aliases)
}

# --- messaging ---------------------------------------------------------------

scan_sns() {
  local p="$1" r="$2"

  local topics
  topics="$(rows_from "$p" "$r" '.Topics[]?.TopicArn' sns list-topics)"
  while IFS= read -r arn; do
    [ -n "$arn" ] || continue
    local name
    name="$(printf '%s' "$arn" | awk -F: '{print $NF}')"
    local attrs="" tags="" mng="unknown" subs="0" display=""
    if detail_budget; then
      attrs="$(aws_json "$p" "$r" sns get-topic-attributes --topic-arn "$arn")" || attrs=""
      [ -n "$attrs" ] && subs="$(printf '%s' "$attrs" | jqr 'n(.Attributes.SubscriptionsConfirmed)')"
      [ -n "$attrs" ] && display="$(printf '%s' "$attrs" | jqr 'n(.Attributes.DisplayName)')"
      local tj
      tj="$(aws_json "$p" "$r" sns list-tags-for-resource --resource-arn "$arn")" || tj=""
      [ -n "$tj" ] && tags="$(printf '%s' "$tj" | jqr 'tagstr')" && mng="$(printf '%s' "$tj" | jqr 'managed')"
    fi
    row sns topic "$r" "${display:-$name}" "$arn" aws_sns_topic "$arn" "$mng" \
      "$(attrib_stack "$name" "")" "$([ "$subs" = "0" ] && printf 'no-subscribers' || printf 'active')" \
      "subscriptions_confirmed=$subs|display_name=$display|tags=$tags"
  done <<< "$topics"
}

scan_sqs() {
  local p="$1" r="$2"

  local queues
  queues="$(rows_from "$p" "$r" '.QueueUrls[]?' sqs list-queues)"
  while IFS= read -r url; do
    [ -n "$url" ] || continue
    local name
    name="$(printf '%s' "$url" | awk -F/ '{print $NF}')"
    local attrs="" tags="" mng="unknown" msgs="0" retention=""
    if detail_budget; then
      attrs="$(aws_json "$p" "$r" sqs get-queue-attributes --queue-url "$url" --attribute-names All)" || attrs=""
      [ -n "$attrs" ] && msgs="$(printf '%s' "$attrs" | jqr 'n(.Attributes.ApproximateNumberOfMessages)')"
      [ -n "$attrs" ] && retention="$(printf '%s' "$attrs" | jqr 'n(.Attributes.MessageRetentionPeriod)')"
      local tj
      tj="$(aws_json "$p" "$r" sqs list-queue-tags --queue-url "$url")" || tj=""
      [ -n "$tj" ] && tags="$(printf '%s' "$tj" | jqr 'tagstr')" && mng="$(printf '%s' "$tj" | jqr 'managed')"
    fi
    row sqs queue "$r" "$name" "$url" aws_sqs_queue "$url" "$mng" "$(attrib_stack "$name" "")" \
      "$([ "$msgs" = "0" ] && printf 'empty' || printf 'has-messages')" \
      "url=$url|messages=$msgs|retention_seconds=$retention|tags=$tags"
  done <<< "$queues"
}

scan_lambda() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r arn name runtime mem timeout desc modified size; do
    [ -n "$name" ] || continue
    local tags="" mng="unknown"
    if detail_budget; then
      local tj
      tj="$(aws_json "$p" "$r" lambda list-tags --resource "$arn")" || tj=""
      [ -n "$tj" ] && tags="$(printf '%s' "$tj" | jqr '{Tags: .Tags} | tagstr')" && mng="$(printf '%s' "$tj" | jqr '{Tags: .Tags} | managed')"
    fi
    case "$size" in ''|*[!0-9]*) size=0 ;; esac
    row lambda function "$r" "$name" "$arn" aws_lambda_function "$name" "$mng" \
      "$(attrib_stack "$name" "")" "active" \
      "runtime=$runtime|memory_mb=$mem|timeout_s=$timeout|code_size_kb=$((size / 1024))|description=$desc|modified=$modified|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .Functions[]?
    | [ n(.FunctionArn), n(.FunctionName), n(.Runtime), (.MemorySize // 0 | tostring), (.Timeout // 0 | tostring),
        n(.Description), n(.LastModified), (.CodeSize // 0 | tostring) ] | us' \
    lambda list-functions)
}

# --- scheduling / events -----------------------------------------------------

scan_scheduler() {
  local p="$1" r="$2" group

  while IFS=$'\x1f' read -r name arn created; do
    [ -n "$name" ] || continue
    row scheduler schedule-group "$r" "$name" "$arn" aws_scheduler_schedule_group "$name" "unknown" \
      "$(attrib_stack "$name" "")" "active" "created=$created"
  done < <(rows_from "$p" "$r" '
    .ScheduleGroups[]? | [ n(.Name), n(.Arn), n(.CreationDate) ] | us' \
    scheduler list-schedule-groups)

  local groups="default"
  groups="$groups $(rows_from "$p" "$r" '.ScheduleGroups[]?.Name' scheduler list-schedule-groups)"
  for group in $groups; do
    while IFS=$'\x1f' read -r name arn state expr target created mng stg tags; do
      [ -n "$name" ] || continue
      local imp="$name"
      [ "$group" != "default" ] && imp="${group}/${name}"
      row scheduler schedule "$r" "$name" "$arn" aws_scheduler_schedule "$imp" "$mng" \
        "$(attrib_stack "$name" "$stg")" "$state" \
        "group=$group|expression=$expr|target=$target|created=$created|tags=$tags"
    done < <(rows_from "$p" "$r" '
      .Schedules[]?
      | [ n(.Name), n(.Arn), n(.State), n(.ScheduleExpression), n(.Target.Arn), n(.CreationDate),
          managed, tag("Stack"), tagstr ] | us' \
      scheduler list-schedules --group-name "$group")
  done
}

# NOTE: several list APIs (events list-rules, cloudwatch describe-alarms,
# servicediscovery list-*, iam list-policies, kms describe-key, ec2
# describe-flow-logs) return NO tags at all. Reading `managed` off an empty tag
# set would label every one of them "not managed by Terraform" and bury the real
# findings, so those scanners make one extra tag call per resource instead -
# inside detail_budget, so a huge account cannot blow up the runtime.
scan_events() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r name arn state expr bus desc; do
    [ -n "$name" ] || continue
    local tags="" mng="unknown" tj
    if detail_budget; then
      tj="$(aws_json "$p" "$r" events list-tags-for-resource --resource-arn "$arn")" || tj=""
      if [ -n "$tj" ]; then
        tags="$(printf '%s' "$tj" | jqr 'tagstr')"
        mng="$(printf '%s' "$tj" | jqr 'managed')"
      fi
    fi
    row events rule "$r" "$name" "$arn" aws_cloudwatch_event_rule "$name" "$mng" \
      "$(attrib_stack "$name" "")" "$state" \
      "event_bus=$bus|expression=$expr|description=$desc|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .Rules[]?
    | [ n(.Name), n(.Arn), n(.State), n(.ScheduleExpression), n(.EventBusName), n(.Description) ] | us' \
    events list-rules)
}

scan_logs() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r name arn retention bytes created; do
    [ -n "$name" ] || continue
    local tags="" mng="unknown"
    if detail_budget; then
      local tj
      tj="$(aws_json "$p" "$r" logs list-tags-for-resource --resource-identifier "$arn")" || tj=""
      if [ -z "$tj" ]; then
        tj="$(aws_json "$p" "$r" logs list-tags-log-group --log-group-name "$name")" || tj=""
      fi
      [ -n "$tj" ] && tags="$(printf '%s' "$tj" | jqr 'if .tags then {Tags: .tags} else . end | tagstr')" \
                 && mng="$(printf '%s' "$tj" | jqr 'if .tags then {Tags: .tags} else . end | managed')"
    fi
    case "$bytes" in ''|*[!0-9]*) bytes=0 ;; esac
    # The id is the log group NAME (that is what aws_cloudwatch_log_group
    # imports on); the ARN, which list-tags-for-resource needs, keeps its ":*".
    row logs log-group "$r" "$name" "$name" aws_cloudwatch_log_group "$name" "$mng" \
      "$(attrib_stack "$name" "")" "$([ -z "$retention" ] && printf 'never-expires' || printf 'active')" \
      "arn=$arn|retention_days=${retention:-never}|size_mb=$((bytes / 1048576))|created=$created|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .logGroups[]?
    | [ n(.logGroupName), n(.arn), (.retentionInDays // "" | tostring),
        (.storedBytes // 0 | tostring), (.creationTime // "" | tostring) ] | us' \
    logs describe-log-groups)
}

scan_cloudwatch() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r name arn state metric namespace reason; do
    [ -n "$name" ] || continue
    local tags="" mng="unknown" tj
    if detail_budget; then
      tj="$(aws_json "$p" "$r" cloudwatch list-tags-for-resource --resource-arn "$arn")" || tj=""
      if [ -n "$tj" ]; then
        tags="$(printf '%s' "$tj" | jqr 'tagstr')"
        mng="$(printf '%s' "$tj" | jqr 'managed')"
      fi
    fi
    row cloudwatch alarm "$r" "$name" "$arn" aws_cloudwatch_metric_alarm "$name" "$mng" \
      "$(attrib_stack "$name" "")" "$state" \
      "metric=$namespace/$metric|reason=$reason|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .MetricAlarms[]?
    | [ n(.AlarmName), n(.AlarmArn), n(.StateValue), n(.MetricName), n(.Namespace),
        n(.StateReason | head(120)) ] | us' \
    cloudwatch describe-alarms)
}

scan_autoscaling() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r rid dimension mincap maxcap namespace; do
    [ -n "$rid" ] || continue
    row autoscaling scalable-target "$r" "$rid" "$rid" aws_appautoscaling_target "$namespace:$dimension:$rid" \
      "unknown" "$(attrib_stack "$rid" "")" "active" \
      "resource_id=$rid|dimension=$dimension|min=$mincap|max=$maxcap|namespace=$namespace"
  done < <(rows_from "$p" "$r" '
    .ScalableTargets[]?
    | [ n(.ResourceId), n(.ScalableDimension), (.MinCapacity // 0 | tostring), (.MaxCapacity // 0 | tostring),
        n(.ServiceNamespace) ] | us' \
    application-autoscaling describe-scalable-targets --service-namespace ecs)

  while IFS=$'\x1f' read -r name arn minsize maxsize desired instances lct mng stg tags; do
    [ -n "$name" ] || continue
    row autoscaling group "$r" "$name" "$arn" aws_autoscaling_group "$name" "$mng" \
      "$(attrib_stack "$name" "$stg")" "active" \
      "min=$minsize|max=$maxsize|desired=$desired|instances=$instances|launch_config=$lct|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .AutoScalingGroups[]?
    | [ n(.AutoScalingGroupName), n(.AutoScalingGroupARN), (.MinSize // 0 | tostring), (.MaxSize // 0 | tostring),
        (.DesiredCapacity // 0 | tostring), n([.Instances[]?.InstanceId] | join(",")), n(.LaunchTemplate.LaunchTemplateName),
        managed, tag("Stack"), tagstr ] | us' \
    autoscaling describe-auto-scaling-groups)

  while IFS=$'\x1f' read -r name created image type; do
    [ -n "$name" ] || continue
    row autoscaling launch-configuration "$r" "$name" "$name" aws_launch_configuration "$name" "unknown" \
      "$(attrib_stack "$name" "")" "active" "created=$created|image=$image|instance_type=$type"
  done < <(rows_from "$p" "$r" '
    .LaunchConfigurations[]?
    | [ n(.LaunchConfigurationName), n(.CreatedTime), n(.ImageId), n(.InstanceType) ] | us' \
    autoscaling describe-launch-configurations)
}

scan_cloudmap() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r id name type created; do
    [ -n "$id" ] || continue
    local tags="" mng="unknown" tj
    if detail_budget; then
      tj="$(aws_json "$p" "$r" servicediscovery list-tags-for-resource --resource-id "$id")" || tj=""
      [ -n "$tj" ] && tags="$(printf '%s' "$tj" | jqr 'tagstr')" && mng="$(printf '%s' "$tj" | jqr 'managed')"
    fi
    row cloudmap namespace "$r" "$name" "$id" \
      "$([ "$type" = "DNS_PRIVATE" ] && printf 'aws_service_discovery_private_dns_namespace' || printf 'aws_service_discovery_public_dns_namespace')" \
      "$id" "$mng" "$(attrib_stack "$name" "")" "$type" "created=$created|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .Namespaces[]?
    | [ n(.Id), n(.Name), n(.Type), n(.CreateDate) ] | us' \
    servicediscovery list-namespaces)

  while IFS=$'\x1f' read -r id name nsid instances; do
    [ -n "$id" ] || continue
    local tags="" mng="unknown" tj
    if detail_budget; then
      tj="$(aws_json "$p" "$r" servicediscovery list-tags-for-resource --resource-id "$id")" || tj=""
      [ -n "$tj" ] && tags="$(printf '%s' "$tj" | jqr 'tagstr')" && mng="$(printf '%s' "$tj" | jqr 'managed')"
    fi
    row cloudmap service "$r" "$name" "$id" aws_service_discovery_service "$id" "$mng" \
      "$(attrib_stack "$name" "")" "active" "namespace=$nsid|instances=$instances|tags=$tags"
  done < <(rows_from "$p" "$r" '
    .Services[]?
    | [ n(.Id), n(.Name), n(.NamespaceId), (.InstanceCount // 0 | tostring) ] | us' \
    servicediscovery list-services)
}

scan_ssm() {
  local p="$1" r="$2"

  # Parameter VALUES are never fetched: describe-parameters returns names and
  # metadata only, which is all that is needed to know what exists.
  while IFS=$'\x1f' read -r name type tier modified version; do
    [ -n "$name" ] || continue
    row ssm parameter "$r" "$name" "$name" aws_ssm_parameter "$name" "unknown" \
      "$(attrib_stack "$name" "")" "$type" "tier=$tier|modified=$modified|version=$version"
  done < <(rows_from "$p" "$r" '
    .Parameters[]?
    | [ n(.Name), n(.Type), n(.Tier), n(.LastModifiedDate), ((.Version // 0) | tostring) ] | us' \
    ssm describe-parameters)
}

# --- other data stores -------------------------------------------------------

scan_dynamodb() {
  local p="$1" r="$2"

  local tables
  tables="$(rows_from "$p" "$r" '.TableNames[]?' dynamodb list-tables)"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    while IFS=$'\x1f' read -r tname arn status items sizegb billing klass mng stg tags; do
      [ -n "$tname" ] || continue
      row dynamodb table "$r" "$tname" "$arn" aws_dynamodb_table "$tname" "$mng" \
        "$(attrib_stack "$tname" "$stg")" "$status" \
        "items=$items|size_gb=$sizegb|billing=$billing|class=$klass|tags=$tags"
    done < <(rows_from "$p" "$r" '
      .Table
      | [ n(.TableName), n(.TableArn), n(.TableStatus), (.ItemCount // 0 | tostring),
          (num(.TableSizeBytes) / 1073741824 | tostring), n(.BillingModeSummary.BillingMode),
          n(.TableClassSummary.TableClass), managed, tag("Stack"), tagstr ] | us' \
      dynamodb describe-table --table-name "$name")
  done <<< "$tables"
}

scan_elasticache() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r id engine status node_type nodes transit; do
    [ -n "$id" ] || continue
    row elasticache cluster "$r" "$id" "$id" aws_elasticache_cluster "$id" "unknown" \
      "$(attrib_stack "$id" "")" "$status" \
      "engine=$engine|node_type=$node_type|nodes=$nodes|encryption_in_transit=$transit"
  done < <(rows_from "$p" "$r" '
    .CacheClusters[]?
    | [ n(.CacheClusterId), n(.Engine), n(.CacheClusterStatus), n(.CacheNodeType),
        ((.NumCacheNodes // 0) | tostring), (.TransitEncryptionEnabled | tostring) ] | us' \
    elasticache describe-cache-clusters)

  while IFS=$'\x1f' read -r id engine status nodes; do
    [ -n "$id" ] || continue
    row elasticache replication-group "$r" "$id" "$id" aws_elasticache_replication_group "$id" "unknown" \
      "$(attrib_stack "$id" "")" "$status" "engine=$engine|node_groups=$nodes"
  done < <(rows_from "$p" "$r" '
    .ReplicationGroups[]?
    | [ n(.ReplicationGroupId), n(.Engine), n(.Status), (.MemberClusters | length | tostring) ] | us' \
    elasticache describe-replication-groups)

  while IFS=$'\x1f' read -r name vpc subnets; do
    [ -n "$name" ] || continue
    row elasticache subnet-group "$r" "$name" "$name" aws_elasticache_subnet_group "$name" "unknown" \
      "$(attrib_stack "$name" "")" "active" "vpc=$vpc|subnets=$subnets"
  done < <(rows_from "$p" "$r" '
    .CacheSubnetGroups[]?
    | select(.CacheSubnetGroupName != "default")
    | [ n(.CacheSubnetGroupName), n(.VpcId), n([.Subnets[]?.SubnetIdentifier] | join(",")) ] | us' \
    elasticache describe-cache-subnet-groups)
}

scan_opensearch() {
  local p="$1" r="$2" svc="opensearch"

  rows_from "$p" "$r" '.DomainNames[]?' opensearch list-domain-names >/dev/null 2>&1 || svc="es"

  local domains
  domains="$(rows_from "$p" "$r" '.DomainNames[]?.DomainName' "$svc" list-domain-names)"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    while IFS=$'\x1f' read -r dname arn status engine version endpoint; do
      [ -n "$dname" ] || continue
      row opensearch domain "$r" "$dname" "$arn" aws_opensearch_domain "$dname" "unknown" \
        "$(attrib_stack "$dname" "")" "$status" \
        "engine=$engine-$version|endpoint=$endpoint"
    done < <(rows_from "$p" "$r" '
      .DomainStatus
      | [ n(.DomainName), n(.ARN), n(if .Deleted then "deleted" else "active" end), n(.EngineVersion),
          n(.ClusterConfig.InstanceType), n(.Endpoint) ] | us' \
      "$svc" describe-domain --domain-name "$name")
  done <<< "$domains"
}

scan_ses() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r identity; do
    [ -n "$identity" ] || continue
    row ses identity "$r" "$identity" "$identity" aws_ses_domain_identity "$identity" "unknown" \
      "$(attrib_stack "$identity" "")" "active" "-"
  done < <(rows_from "$p" "$r" '.Identities[]?' ses list-identities --identity-type Domain)

  while IFS=$'\x1f' read -r name; do
    [ -n "$name" ] || continue
    row ses configuration-set "$r" "$name" "$name" aws_ses_configuration_set "$name" "unknown" \
      "$(attrib_stack "$name" "")" "active" "-"
  done < <(rows_from "$p" "$r" '.ConfigurationSets[]?.Name' ses list-configuration-sets)
}

# --- governance / hygiene ----------------------------------------------------

scan_governance() {
  local p="$1" r="$2"

  while IFS=$'\x1f' read -r name arn bucket multi org status; do
    [ -n "$arn" ] || continue
    row governance cloudtrail "$r" "$name" "$arn" aws_cloudtrail "$name" "unknown" \
      "$(attrib_stack "$name" "")" "$status" \
      "s3_bucket=$bucket|multi_region=$multi|organization_trail=$org"
  done < <(rows_from "$p" "$r" '
    .trailList[]?
    | [ n(.Name), n(.TrailARN), n(.S3BucketName), (.IsMultiRegionTrail | tostring),
        (.IsOrganizationTrail | tostring), n(if .IsLogging then "logging" else "not-logging" end) ] | us' \
    cloudtrail describe-trails)

  while IFS=$'\x1f' read -r name role status; do
    [ -n "$name" ] || continue
    row governance config-recorder "$r" "$name" "$name" aws_config_configuration_recorder "$name" "unknown" \
      "$(attrib_stack "$name" "")" "$status" "iam_role=$role"
  done < <(rows_from "$p" "$r" '
    .ConfigurationRecorders[]?
    | [ n(.name), n(.roleARN), n(.recordingGroup.allSupported | tostring) ] | us' \
    configservice describe-configuration-recorders)

  while IFS=$'\x1f' read -r id status; do
    [ -n "$id" ] || continue
    row governance guardduty-detector "$r" "$id" "$id" aws_guardduty_detector "$id" "unknown" \
      "$(attrib_stack "$id" "")" "$status" "-"
  done < <(rows_from "$p" "$r" '.Detectors[]? | [.DetectorId, .Status] | us' guardduty list-detectors)

  if [ -n "$CUR_ACCOUNT" ]; then
    while IFS=$'\x1f' read -r name period calc; do
      [ -n "$name" ] || continue
      row governance budget "$r" "$name" "$name" aws_budgets_budget "$CUR_ACCOUNT:$name" "unknown" \
        "$(attrib_stack "$name" "")" "active" "period=$period|calculation=$calc"
    done < <(rows_from "$p" "us-east-1" '
      .Budgets[]?
      | [ n(.BudgetName), n(.TimeUnit), n(.CalculatedSpend.ActualSpend.Amount) ] | us' \
      budgets describe-budgets --account-id "$CUR_ACCOUNT")
  fi
}

# =============================================================================
# REPORTING
# =============================================================================

# md_table "Header 1|Header 2|..." - turns TSV on stdin into a markdown table.
md_table() {
  awk -F'\t' -v h="$1" '
    function esc(s) { gsub(/\|/, "/", s); return s }
    BEGIN {
      n = split(h, H, "|")
      printf "|"
      for (i = 1; i <= n; i++) printf " %s |", H[i]
      printf "\n|"
      for (i = 1; i <= n; i++) printf " --- |"
      printf "\n"
    }
    NF > 0 {
      printf "|"
      for (i = 1; i <= n; i++) printf " %s |", (i <= NF ? esc($i) : "")
      printf "\n"
    }'
}

# Findings: cost, security and hygiene items derived from the inventory. This is
# the part that turns a list of resources into something to act on.
FINDINGS_AWK='
function dv(d, k,   arr, i, n, kv, p) {
  n = split(d, arr, "|")
  for (i = 1; i <= n; i++) {
    p = index(arr[i], "=")
    if (p == 0) continue
    if (substr(arr[i], 1, p - 1) == k) return substr(arr[i], p + 1)
  }
  return ""
}
function add(cat, title, key, ex) {
  cnt[key]++; catof[key] = cat; ttl[key] = title
  if (exc[key]++ < 6) exs[key] = exs[key] (exs[key] == "" ? "" : "; ") ex
}
function label(env, stack, svc, kind, name, id) {
  return stack "/" svc " " name " (" id ")"
}
BEGIN { FS = "\t"; OFS = "\t" }
{
  env = $1; stack = $3; svc = $4; kind = $5; region = $6
  name = $7; id = $8; managed = $11; status = $12; details = $13
  ex = label(env, stack, svc, kind, name, id)

  # ---- cost ---------------------------------------------------------------
  if (kind == "volume" && status == "available")
    { add("cost", "Unattached EBS volumes - storage billed, nothing using it", "vol_avail", ex) }
  if (kind == "elastic-ip" && status == "unassociated")
    { add("cost", "Elastic IPs attached to nothing - every idle public IPv4 is billed", "eip_idle", ex) }
  if (kind == "instance" && status == "stopped")
    { add("cost", "Stopped EC2 instances - EBS and EIP still billed (the dev host is stopped nightly by design, see dev/scheduler.tf)", "ec2_stopped", ex) }
  if (kind == "db-instance" && status == "stopped")
    { add("cost", "Stopped RDS instances - storage still billed, and RDS restarts itself after 7 days", "rds_stopped", ex) }
  if (kind == "snapshot")
    { snap++; snapgb += dv(details, "size_gb") + 0 }
  if (kind == "ami")
    { ami++ }
  if (kind == "nat-gateway" && status != "available" && status != "pending")
    { add("cost", "NAT gateways not in state available - failed or deleted leftovers", "nat_bad", ex) }
  if (kind == "log-group" && status == "never-expires")
    { add("cost", "CloudWatch log groups with no retention - they grow until deleted", "log_noret", ex) }
  if (kind == "load-balancer" && dv(details, "type") == "network")
    { add("cost", "Network Load Balancers - none of the stacks here declare one", "nlb", ex) }
  if (kind == "classic-lb")
    { add("cost", "Classic Load Balancers - previous generation, not in any stack", "clb", ex) }

  # ---- security -----------------------------------------------------------
  if (kind == "security-group" && dv(details, "open_to_world") != "")
    { add("security", "Security groups with ingress open to 0.0.0.0/0 - check the ports against dev/checkov.yml and prod/security_groups.tf", "sg_world", ex " ports=" dv(details, "open_to_world")) }
  if (kind == "bucket" && dv(details, "encryption") == "none")
    { add("security", "S3 buckets with no default encryption - every bucket this repo creates is encrypted", "s3_enc", ex) }
  if (kind == "bucket" && status != "private")
    { add("security", "S3 buckets without a full public access block", "s3_public", ex " public_access=" dv(details, "public_access")) }
  if (kind == "volume" && dv(details, "encrypted") == "false")
    { add("security", "Unencrypted EBS volumes", "ebs_enc", ex) }
  if (kind == "db-instance" && dv(details, "encrypted") == "false")
    { add("security", "RDS instances without storage encryption - cannot be enabled in place, needs a snapshot/restore", "rds_enc", ex) }
  if (kind == "secret" && dv(details, "kms_key") ~ /default/)
    { add("security", "Secrets on the default aws/secretsmanager key instead of a customer KMS key (prod/vault.tf and monitoring/kms.tf use CMKs)", "secret_kms", ex) }
  if (kind == "user" && dv(details, "password_last_used") == "never")
    { add("security", "IAM users that have never signed in - this repo is OIDC only (bootstrap/iam.tf), so console users are probably leftovers", "iam_user_unused", ex) }
  if (kind == "instance" && dv(details, "public_ip") != "" && dv(details, "instance_profile") == "")
    { add("security", "Public EC2 instances with no IAM instance profile", "ec2_noprofile", ex) }

  # ---- hygiene ------------------------------------------------------------
  if (kind == "bucket" && dv(details, "versioning") != "Enabled")
    { add("hygiene", "S3 buckets without versioning - dev/s3_backup.tf and bootstrap/s3.tf both version their buckets", "s3_ver", ex) }
  if (kind == "bucket" && dv(details, "lifecycle") == "no")
    { add("hygiene", "S3 buckets with no lifecycle policy - nothing ever expires or moves to cheaper storage", "s3_lc", ex) }
  if (kind == "repository" && env == "prod" && dv(details, "tag_mutability") == "MUTABLE")
    { add("hygiene", "ECR repos in prod with MUTABLE tags - prod/terraform.auto.tfvars pins IMMUTABLE", "ecr_mut", ex) }
  if (kind == "repository" && dv(details, "scan_on_push") == "false")
    { add("hygiene", "ECR repos without scan-on-push - Trivy in CI only sees the code, not the images", "ecr_scan", ex) }
  if (kind == "repository" && dv(details, "lifecycle_policy") == "no")
    { add("hygiene", "ECR repos with no lifecycle policy - untagged images pile up forever (both stacks set ecr_images_to_keep)", "ecr_lc", ex) }
  if (kind == "certificate" && (status == "EXPIRED" || status == "FAILED" || status == "PENDING_VALIDATION"))
    { add("hygiene", "ACM certificates that are not issued - an ALB listener cannot use them", "acm_bad", ex " status=" status) }
  if (kind == "db-instance" && env == "prod" && dv(details, "multi_az") == "false")
    { add("hygiene", "Single-AZ RDS in prod - expected while mssql_multi_az = false, listed so the go-live flip is not forgotten", "rds_az", ex) }
  if (kind == "db-instance" && dv(details, "class") ~ /db\.t[0-9]*\.micro/)
    { add("hygiene", "db.t*.micro database instances - the Express/1 GiB ceiling documented in prod/terraform.auto.tfvars applies", "rds_micro", ex) }

  # ---- things that are missing entirely -----------------------------------
  if (kind == "cloudtrail") seen_trail++
  if (kind == "guardduty-detector") seen_gd++
  if (kind == "config-recorder") seen_cfg++
  if (kind == "budget") seen_budget++
}
function missing(cat, title, key) {
  # cnt 0 marks "this whole type is absent", which the report renders as
  # "none found" rather than a nonsense count of one.
  cnt[key] = 0; catof[key] = cat; ttl[key] = title; exs[key] = ""
}
END {
  if (!seen_trail)  missing("security", "No CloudTrail trail - API activity in this account is not being recorded", "no_trail")
  if (!seen_gd)     missing("security", "No GuardDuty detector - no threat detection on the account", "no_gd")
  if (!seen_cfg)    missing("hygiene", "No AWS Config recorder - nothing tracks configuration drift, which is what makes unmanaged resources hard to spot", "no_cfg")
  if (!seen_budget) missing("cost", "No AWS Budget - the README quotes a ~$250-300/month envelope nobody is alerted on", "no_budget")
  if (snap) { cnt["snap_total"] = snap; catof["snap_total"] = "cost"; ttl["snap_total"] = "EBS snapshots held - none of the stacks create snapshots, so these are manual or from AWS Backup"; exs["snap_total"] = snapgb " GiB total" }
  if (ami)  { cnt["ami_total"] = ami; catof["ami_total"] = "cost"; ttl["ami_total"] = "Private AMIs - unused ones are pure storage cost"; exs["ami_total"] = ami " image(s)" }
  for (k in cnt) print catof[k], ttl[k], cnt[k], exs[k]
}'

# write_findings <tsv> -> findings.tsv sorted by category then count
write_findings() {
  awk -F'\t' "$FINDINGS_AWK" "$1" 2>/dev/null | sort -t"$(printf '\t')" -k1,1 -k3,3nr
}

# tsv (stdin) -> quoted csv (Excel/Sheets friendly)
tsv_to_csv() {
  awk -F'\t' '
    function q(s) { gsub(/"/, "\"\"", s); return "\"" s "\"" }
    { out = ""; for (i = 1; i <= NF; i++) out = out (i > 1 ? "," : "") q($i); print out }'
}

# =============================================================================
# IMPORT BLOCKS
# =============================================================================

# Terraform >= 1.5 import blocks. Written as *.tf.txt because dev/discovery/ is
# INSIDE the dev root module: a real .tf file there is loaded by every
# `terraform plan -chdir=dev`, and CI would try to import all of AWS.
GEN_IMPORTS_AWK='
BEGIN {
  FS = "\t"
  dir["dev"] = dev_dir; dir["prod"] = prod_dir; dir["monitoring"] = mon_dir
  split("dev prod monitoring", order, " ")
}
function sanitize(s) { gsub(/[^A-Za-z0-9]/, "_", s); return substr(s, 1, 48) }
function f(stack) { return dir[stack] "/imports/imports-" stack ".tf.txt" }
function head(stack, env, ts,   file) {
  file = f(stack)
  print "# ---------------------------------------------------------------------------" > file
  print "# Generated by scripts/aws-inventory-scan.sh - DO NOT EDIT BY HAND." > file
  print "# Source: " env " account scan of " ts > file
  print "#" > file
  print "# These are the resources found in AWS that are NOT tagged ManagedBy=terraform," > file
  print "# i.e. not created by this repo. They are import candidates, not a shopping list:" > file
  print "#" > file
  print "#   1. Delete every block you do not want under Terraform (most hand-made" > file
  print "#      resources should be deleted or replaced, not adopted)." > file
  print "#   2. Copy what is left into " stack "/imports.tf - this file is .tf.txt on" > file
  print "#      purpose, because " stack "/discovery/ is inside the " stack " root module" > file
  print "#      and a .tf file here would be picked up by every local plan and by CI." > file
  print "#   3. Generate the resource config instead of writing it by hand:" > file
  print "#        terraform -chdir=" stack " plan -generate-config-out=generated.tf" > file
  print "#   4. Move the generated blocks into a real .tf file (ec2.tf, s3.tf, ...)," > file
  print "#      delete the import blocks, then plan again: it must report" > file
  print "#      \"0 to add, 0 to change, 0 to destroy\". Anything else means the" > file
  print "#      generated config does not match reality - fix the config, not AWS." > file
  print "#" > file
  print "# Import ID formats below follow the AWS provider docs for the common case;" > file
  print "# a few resources (task definitions, scheduler entries, target groups behind" > file
  print "# several LBs) have fiddlier formats - the provider page for that resource is" > file
  print "# the authority: https://registry.terraform.io/providers/hashicorp/aws/latest/docs" > file
  print "# ---------------------------------------------------------------------------" > file
  print "" > file
  opened[stack] = 1
}
$11 == "no" && $9 != "" && $10 != "" {
  stack = $3
  if (!(stack in dir)) stack = "prod"
  if (!(stack in opened)) head(stack, $1, ts)
  file = f(stack)
  addr = "discovered_" sanitize($10)
  if (seen[stack, addr]++) addr = addr "_" seen[stack, addr]
  d = $13; if (length(d) > 150) d = substr(d, 1, 150) "..."
  print "# " $4 "/" $5 " " $7 "  [region " $6 ", status " $12 "]" > file
  print "#   " d > file
  print "import {" > file
  print "  to = " $9 "." addr > file
  print "  id = \"" $10 "\"" > file
  print "}" > file
  print "" > file
  count[stack]++
}
END {
  for (i = 1; i <= 3; i++) {
    s = order[i]
    if (s in count) print s "\t" count[s] "\t" f(s)
  }
}'

# =============================================================================
# STATE CROSS-CHECK (--with-state)
# =============================================================================

# Resources that cannot be tagged (Route53 records above all) come out as
# managed=unknown. Reading the real state settles them: any discovered id that
# appears in `terraform show -json` is definitely in code.
load_state_ids() {
  local stack="$1"
  # Two statements on purpose: `local a="$1" b="${a}.txt"` expands ${a} before
  # the assignment lands, which under `set -u` dies with "a: unbound variable".
  local ids_file="$CUR_RUN/state-${stack}.txt"
  : > "$ids_file"

  # These messages are captured by the caller and printed with its own "!", so
  # they carry no prefix here.
  if ! command -v terraform >/dev/null 2>&1; then
    say "terraform is not on PATH - skipping the state check for ${stack}/"
    return 1
  fi
  if [ ! -d "$REPO_ROOT/$stack/.terraform" ]; then
    say "${stack}/ has no .terraform/ - run 'terraform -chdir=${stack} init' first, then re-run with --with-state"
    return 1
  fi

  local out
  out="$(AWS_PROFILE="$CUR_PROFILE" TF_IN_AUTOMATION=true \
    terraform -chdir="$REPO_ROOT/$stack" show -json -no-color 2>>"$CUR_PERM")" || {
      say "terraform show -json failed for ${stack}/ (see runs/${TIMESTAMP}/permissions.log)"
      return 1
    }
  printf '%s' "$out" | jq -r '[.. | strings] | .[]' 2>/dev/null \
    | awk 'length($0) > 2' | sort -u > "$ids_file"

  if [ ! -s "$ids_file" ]; then
    say "no identifiers came back from ${stack}/ state"
    return 1
  fi
  ok "state check: $(wc -l < "$ids_file" | tr -d ' ') identifiers loaded from ${stack}/"
  return 0
}

apply_state_ids() {
  local ids_file="$1" tmp="$CUR_RUN/inventory.state.tsv" matched
  [ -s "$ids_file" ] || return 0
  awk -F'\t' -v OFS='\t' -v ids="$ids_file" '
    BEGIN { while ((getline line < ids) > 0) if (line != "") known[line] = 1 }
    {
      if ($11 != "yes" && (($8 != "" && ($8 in known)) || ($10 != "" && ($10 in known)))) {
        $11 = "yes"
        $13 = $13 "|in_terraform_state=yes"
        hit++
      }
      print
    }
    END { printf "%d", hit + 0 > "/dev/stderr" }' "$CUR_TSV" > "$tmp" 2>"$CUR_RUN/.matched"
  matched="$(cat "$CUR_RUN/.matched" 2>/dev/null || echo 0)"
  rm -f "$CUR_RUN/.matched"
  mv "$tmp" "$CUR_TSV"
  STATE_MATCHED=$((STATE_MATCHED + matched))
  [ "$matched" -gt 0 ] && ok "state check: $matched resource(s) confirmed already in Terraform state"
  return 0
}

# =============================================================================
# PER-ENVIRONMENT SUMMARY
# =============================================================================

# Counters filled in by scan_env and printed into the summary.
SUM_LABEL=""
SUM_PROFILE=""
SUM_ACCOUNT=""
SUM_ARN=""
SUM_REGIONS=""
SUM_DURATION=0
SUM_SOURCE=""
SUM_API_NOTE=""
SUM_SERVICES=""
STATE_MATCHED=0

# write_summary <tsv> <discovery-dir>
# Everything in SUMMARY.md is derived from the inventory TSV, so the same
# function writes the dev report, the prod report and the monitoring extract.
write_summary() {
  local tsv="$1" dir="$2" out="$2/SUMMARY.md"

  local total yes no unk
  total="$(awk 'END { print NR + 0 }' "$tsv")"
  yes="$(awk -F'\t' '$11 == "yes"' "$tsv" | awk 'END { print NR + 0 }')"
  no="$(awk -F'\t' '$11 == "no"' "$tsv" | awk 'END { print NR + 0 }')"
  unk="$(awk -F'\t' '$11 == "unknown"' "$tsv" | awk 'END { print NR + 0 }')"

  local services kinds
  services="$(awk -F'\t' '{ print $4 }' "$tsv" | sort -u | grep -c . || true)"
  kinds="$(awk -F'\t' '{ print $4 "/" $5 }' "$tsv" | sort -u | grep -c . || true)"

  {
    printf '# AWS discovery - %s (account %s)\n\n' "$SUM_LABEL" "$SUM_ACCOUNT"
    printf 'Generated by `scripts/aws-inventory-scan.sh` at `%s` in %ss - read only, nothing in AWS was changed.\n\n' "$TIMESTAMP" "$SUM_DURATION"
    printf '| | |\n| --- | --- |\n'
    printf '| Profile | `%s` |\n' "$SUM_PROFILE"
    printf '| Account | `%s` (`%s`) |\n' "$SUM_ACCOUNT" "$SUM_ARN"
    printf '| Regions | `%s` |\n' "$SUM_REGIONS"
    if [ -n "$SUM_SERVICES" ]; then
      printf '| Services scanned | `%s` ONLY - a service missing from this report was not scanned, not absent |\n' "$SUM_SERVICES"
    fi
    printf '| AWS CLI | `%s` |\n' "$AWS_CLI_VERSION"
    [ -n "$SUM_SOURCE" ] && printf '| Note | %s |\n' "$SUM_SOURCE"
    printf '\n'

    printf '## Headline\n\n'
    printf '| | Count |\n| --- | --- |\n'
    printf '| Resources found | %s |\n' "$total"
    printf '| Service / kind combinations | %s services, %s kinds |\n' "$services" "$kinds"
    printf '| Already managed by this repo (`ManagedBy=terraform`) | %s |\n' "$yes"
    printf '| **Import candidates (not tagged as Terraform-managed)** | **%s** |\n' "$no"
    printf '| Cannot be decided from tags (resource type is not taggable) | %s |\n' "$unk"
    [ "$STATE_MATCHED" -gt 0 ] && printf '| Confirmed present in Terraform state (`--with-state`) | %s |\n' "$STATE_MATCHED"
    if [ -n "$SUM_API_NOTE" ]; then
      printf '| API calls | %s |\n' "$SUM_API_NOTE"
    else
      printf '| API calls made | %s |\n' "$API_CALLS"
      printf '| API calls that failed | %s (see `runs/%s/permissions.log`) |\n' "$API_FAILS" "$TIMESTAMP"
    fi
    printf '\n'

    printf '### How to read "import candidate"\n\n'
    printf 'Every stack in this repo sets provider `default_tags` with `ManagedBy = "terraform"`\n'
    printf '(`dev/versions.tf`, `prod/versions.tf`, `monitoring/versions.tf`). A resource carrying\n'
    printf 'that tag was created by this repo. A resource without it was created some other way -\n'
    printf 'console, CLI, another tool, or an older stack - and is a candidate to bring in.\n\n'
    printf 'A candidate is NOT automatically something to import: plenty of them are leftovers that\n'
    printf 'should be deleted instead. Read the table below, then decide per resource.\n\n'

    printf '## Import candidates by target stack\n\n'
    if [ "$no" -eq 0 ]; then
      printf 'None - everything discovered is tagged `ManagedBy=terraform`.\n\n'
    else
      awk -F'\t' -v imp="$GEN_IMPORTS" '
        $11 == "no" && $9 != "" && $10 != "" { c[$3]++; i[$3]++ }
        $11 == "no" && ($9 == "" || $10 == "") { c[$3]++; noi[$3]++ }
        END {
          for (s in c)
            printf "%s\t%d\t%s\n", s, c[s],
              (imp == "1" && (s in i) ? "discovery/imports/imports-" s ".tf.txt" : "manual - no import ID for that type")
        }' "$tsv" | sort | md_table "Stack folder|Candidates|Import blocks"
      printf '\n'
    fi

    printf '## Resources by service\n\n'
    awk -F'\t' '
      { k = $4 "\t" $5; tot[k]++; m[$11, k]++ }
      END {
        for (k in tot) {
          split(k, p, "\t")
          printf "%s\t%s\t%d\t%d\t%d\t%d\n", p[1], p[2], tot[k], m["yes", k] + 0, m["no", k] + 0, m["unknown", k] + 0
        }
      }' "$tsv" | sort | md_table "Service|Kind|Total|Managed|Candidates|Unknown"
    printf '\n'

    printf '## Import candidates\n\n'
    if [ "$no" -gt 0 ]; then
      awk -F'\t' '$11 == "no" { printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $3, $4, $5, $6, $7, $8, $9, $10 }' "$tsv" \
        | sort | head -60 \
        | md_table "Stack|Service|Kind|Region|Name|ID|Terraform type|Import ID"
      [ "$no" -gt 60 ] && printf '\n_First 60 of %s - the full list is in `unmanaged.csv`._\n' "$no"
      printf '\n'
    fi

    if [ "$unk" -gt 0 ]; then
      printf '## Cannot be decided from tags\n\n'
      printf 'These resource types do not support tags, so the scan cannot tell whether this repo\n'
      printf 'created them. Re-run with `--with-state` to settle them against real Terraform state,\n'
      printf 'or check by name. Route53 records are the usual bulk here: `prod/route53.tf` owns the\n'
      printf 'whole `nomaos.com` zone including the `dev.` records, so most of them are already managed.\n\n'
      awk -F'\t' '$11 == "unknown" { c[$4 "\t" $5]++ } END { for (k in c) { split(k, p, "\t"); printf "%s\t%s\t%d\n", p[1], p[2], c[k] } }' "$tsv" \
        | sort | md_table "Service|Kind|Count"
      printf '\n'
    fi

    printf '## Findings worth acting on\n\n'
    local findings="$dir/runs/$TIMESTAMP/findings.tsv"
    if [ ! -s "$findings" ]; then
      printf 'Nothing flagged.\n\n'
    else
      local cat found=0
      for cat in cost security hygiene; do
        if awk -F'\t' -v c="$cat" '$1 == c { n++ } END { exit (n > 0 ? 0 : 1) }' "$findings"; then
          found=1
          printf '### %s\n\n' "$cat"
          awk -F'\t' -v c="$cat" '$1 == c {
            if ($3 == 0) { printf "- **%s** - none found\n", $2; next }
            printf "- **%s** - %s resource(s)\n", $2, $3
            if ($4 != "") printf "  - e.g. %s\n", $4
          }' "$findings"
          printf '\n'
        fi
      done
      [ "$found" = "0" ] && printf 'Nothing flagged.\n\n'
    fi

    if [ -s "$dir/runs/$TIMESTAMP/failed-calls.tsv" ]; then
      printf '## API calls that failed\n\n'
      printf 'A failed call means that service was not scanned, not that it is empty. Usually a missing\n'
      printf 'read permission on the role being used - add it and re-run, or accept the gap.\n\n'
      awk -F'\t' '
        { c[$3]++; if (!($3 in s)) s[$3] = $4 }
        END { for (k in c) printf "%s\t%d\t%s\n", k, c[k], s[k] }' "$dir/runs/$TIMESTAMP/failed-calls.tsv" \
        | sort | md_table "Service|Failed calls|Operation"
      printf '\n'
      local denied
      denied="$(sed -n 's/.*An error occurred (\([A-Za-z]*\)).*/\1/p' "$dir/runs/$TIMESTAMP/permissions.log" 2>/dev/null | sort | uniq -c | sort -rn | head -5)"
      if [ -n "$denied" ]; then
        printf '```text\n%s\n```\n\n' "$denied"
      fi
    fi

    cat <<'HOWTO'
## Bringing a candidate into this repo

1. **Decide first.** For each candidate: does it belong in Terraform, or should it be
   deleted? Anything created for a one-off test is usually cheaper to delete than to
   adopt, and adopting it means writing and maintaining its config.
2. **Pick the stack.** `dev/` for the dev account, `prod/` for prod, `monitoring/` for
   the observability stack that lives in the prod account. A resource that serves all
   three (the Route53 zone, say) belongs where the code already is - see README.md.
3. **Generate the config instead of writing it.** Copy the blocks you want from
   `discovery/imports/imports-<stack>.tf.txt` into `<stack>/imports.tf`, then:

   ```bash
   terraform -chdir=<stack> init
   terraform -chdir=<stack> plan -generate-config-out=generated.tf
   ```

   Terraform writes `generated.tf` with the real, live configuration of each resource.
4. **Tidy.** Move the generated resources into the file where they belong (`ec2.tf`,
   `s3.tf`, `security_groups.tf`, ...), replace hard-coded values with the existing
   `var.*` / `local.*` conventions, and **delete the import blocks** - they are
   one-shot, and leaving them in makes the next plan fail once the resource is in state.
5. **Prove nothing will change.** `terraform -chdir=<stack> plan` must report
   `0 to add, 0 to change, 0 to destroy`. Any diff means the config you wrote does not
   match what exists; fix the config (or accept a deliberate change), never let an
   import plan destroy something live.
6. **Let CI check it.** `./scripts/run_test_suite.sh <stack>` runs `terraform test` and
   the coverage gate, and the pipeline adds Checkov, Trivy, Sonar and Infracost. New
   resources normally need a test case in `<stack>/tests/` to keep coverage up.

## Files in this folder

| File | What it is |
| --- | --- |
| `SUMMARY.md` | this report |
| `inventory.tsv` | every resource found, tab separated - the input for the tables above |
| `inventory.csv` | the same, quoted for Excel / Google Sheets |
| `unmanaged.csv` | import candidates only (`managed = no`) |
| `unverifiable.tsv` | resources whose type cannot be tagged (`managed = unknown`) |
| `imports/imports-<stack>.tf.txt` | ready-to-paste `import` blocks, per target stack |
| `runs/<timestamp>/raw/*.json` | the raw response of every AWS call that succeeded |
| `runs/<timestamp>/meta.json` | who/when/how-long/which-regions for this run |
| `runs/<timestamp>/findings.tsv` | the findings table above, machine readable |
| `runs/<timestamp>/failed-calls.tsv` | every AWS call that failed |
| `runs/<timestamp>/permissions.log` | the AWS CLI's own error text for those calls |

Old runs are pruned automatically (`--keep-runs`, default 5). The whole `discovery/`
tree is gitignored: it contains account IDs, IP addresses and internal hostnames, and
this repo is public. To keep one curated snapshot anyway:

```bash
git add -f dev/discovery/SUMMARY.md
```
HOWTO
  } > "$out"
}

# =============================================================================
# FINISH ONE ENVIRONMENT: stable files, findings, imports, summary
# =============================================================================

# stable_outputs <tsv-without-header> <dir>
# Writes inventory.tsv (with header), inventory.csv, unmanaged.csv and
# unverifiable.tsv - the four files that always describe the latest run.
stable_outputs() {
  local tsv="$1" dir="$2" tmp
  TAB="$(printf '\t')"

  { printf '%s\n' "$INVENTORY_HEADER"; sort -t"$TAB" -k3,3 -k4,4 -k5,5 -k6,6 -k7,7 "$tsv"; } > "$dir/inventory.tsv"
  tsv_to_csv < "$dir/inventory.tsv" > "$dir/inventory.csv"

  # The header goes through tsv_to_csv as well: it is tab separated like every
  # other row, and a raw tab header in a quoted CSV reads as a single column.
  tmp="$dir/.unmanaged.tsv"
  awk -F'\t' '$11 == "no"' "$tsv" > "$tmp"
  { printf '%s\n' "$INVENTORY_HEADER"; cat "$tmp"; } | tsv_to_csv > "$dir/unmanaged.csv"
  rm -f "$tmp"

  awk -F'\t' '$11 == "unknown"' "$tsv" > "$dir/unverifiable.tsv"
}

# clean_imports - drop the previous run's import blocks. Called even with
# --no-imports: a stale imports-<stack>.tf.txt left behind by an earlier scan
# describes resources that may no longer exist, and pasting it would be worse
# than having no file at all.
clean_imports() {
  local st
  for st in "$DEV_DIR" "$PROD_DIR" "$MONITORING_DIR"; do
    rm -f "$REPO_ROOT/$st/discovery/imports"/imports-*.tf.txt 2>/dev/null
  done
}

# gen_imports <tsv>
# Writes one import-block file per target stack, and lists what it wrote.
gen_imports() {
  local tsv="$1" st

  # Only create the folders a candidate actually points at.
  for st in $(awk -F'\t' '$11 == "no" && $9 != "" && $10 != "" { print $3 }' "$tsv" | sort -u); do
    mkdir -p "$REPO_ROOT/$st/discovery/imports"
  done

  awk -F'\t' \
    -v dev_dir="$REPO_ROOT/$DEV_DIR/discovery" \
    -v prod_dir="$REPO_ROOT/$PROD_DIR/discovery" \
    -v mon_dir="$REPO_ROOT/$MONITORING_DIR/discovery" \
    -v ts="$TIMESTAMP" \
    "$GEN_IMPORTS_AWK" "$tsv" > "$CUR_RUN/imports-written.tsv"
}

# write_meta <env> <stack-dir> <duration> <regions>
write_meta() {
  local env="$1" dir="$2" duration="$3" regions="$4"
  jq -n \
    --arg env "$env" \
    --arg profile "$CUR_PROFILE" \
    --arg account "$CUR_ACCOUNT" \
    --arg arn "$CUR_ARN" \
    --arg regions "$regions" \
    --arg ts "$TIMESTAMP" \
    --arg cli "$AWS_CLI_VERSION" \
    --arg script "scripts/aws-inventory-scan.sh" \
    --argjson duration "$duration" \
    --argjson rows "$ROWS" \
    --argjson api_calls "$API_CALLS" \
    --argjson api_fails "$API_FAILS" \
    --argjson raw_files "$RAW_FILES" \
    --argjson state_matched "$STATE_MATCHED" \
    --argjson with_state "$WITH_STATE" \
    '{ generated_at: $ts, script: $script, environment: $env, profile: $profile,
       account_id: $account, caller_arn: $arn, regions: ($regions | split(" ")),
       aws_cli: $cli, duration_seconds: $duration, resources_found: $rows,
       api_calls: $api_calls, api_calls_failed: $api_fails, raw_responses_saved: $raw_files,
       confirmed_in_terraform_state: $state_matched, state_check: (if $with_state == 1 then "on" else "off" end),
       read_only: true }' > "$dir/meta.json"
}

prune_runs() {
  local dir="$1"
  [ -d "$dir/runs" ] || return 0
  find "$dir/runs" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sort -r | tail -n +$((KEEP_RUNS + 1)) \
    | while IFS= read -r old; do rm -rf "$old"; done
}

finalize_env() {
  local env="$1" stack_dir="$2" duration="$3" regions="$4"
  local disc="$REPO_ROOT/$stack_dir/discovery"

  header "Writing the ${env} report to ${stack_dir}/discovery/"

  # 1. Optional: settle the untaggable resources against real state.
  if [ "$WITH_STATE" = "1" ]; then
    local st
    for st in $stack_dir $( [ "$env" = "prod" ] && printf 'monitoring' ); do
      local ids
      if ids="$(load_state_ids "$st" 2>&1)"; then
        apply_state_ids "$CUR_RUN/state-${st}.txt"
      else
        warn "$ids"
      fi
    done
  fi

  # 2. Findings, before anything reads the inventory.
  write_findings "$CUR_TSV" > "$CUR_RUN/findings.tsv"

  # 3. Stable files.
  stable_outputs "$CUR_TSV" "$disc"

  # 4. Import blocks.
  clean_imports
  if [ "$GEN_IMPORTS" = "1" ]; then
    gen_imports "$CUR_TSV"
    while IFS=$'\t' read -r st count path; do
      [ -n "$st" ] || continue
      ok "$count import block(s) for ${st}/ -> ${path#"$REPO_ROOT"/}"
    done < "$CUR_RUN/imports-written.tsv"
    if [ ! -s "$CUR_RUN/imports-written.tsv" ]; then
      note "nothing tagged as unmanaged, so no import blocks were needed"
    fi
  else
    note "--no-imports: previous import blocks removed, none written"
  fi

  # 5. The report itself.
  SUM_LABEL="$(printf '%s' "$env" | tr '[:lower:]' '[:upper:]') account"
  SUM_PROFILE="$CUR_PROFILE"
  SUM_ACCOUNT="$CUR_ACCOUNT"
  SUM_ARN="$CUR_ARN"
  SUM_REGIONS="$regions"
  SUM_DURATION="$duration"
  SUM_API_NOTE=""
  SUM_SERVICES="$SERVICE_FILTER"
  local mon_rows=0
  if [ "$env" = "prod" ]; then
    mon_rows="$(awk -F'\t' '$3 == "monitoring"' "$CUR_TSV" | awk 'END { print NR + 0 }')"
    if [ "$mon_rows" -gt 0 ]; then
      SUM_SOURCE="This is the whole prod account, which also hosts the monitoring stack. The $mon_rows resource(s) attributed to monitoring/ are summarised again in \`monitoring/discovery/SUMMARY.md\`."
    fi
  fi
  write_summary "$CUR_TSV" "$disc"

  # 6. Run metadata + housekeeping.
  write_meta "$env" "$CUR_RUN" "$duration" "$regions"
  prune_runs "$disc"

  ok "SUMMARY.md, inventory.csv, unmanaged.csv and imports/ are in ${stack_dir}/discovery/"
  LAST_ENV_TSV="$CUR_TSV"
}

# The monitoring stack lives in the prod account, so its resources turn up in the
# prod scan. Split them out into monitoring/discovery/ so each folder in this repo
# describes the AWS resources that belong to it.
split_monitoring() {
  local src="$REPO_ROOT/$PROD_DIR/discovery/runs/$TIMESTAMP/inventory.tsv"
  [ -s "$src" ] || return 0

  local count
  count="$(awk -F'\t' '$3 == "monitoring"' "$src" | awk 'END { print NR + 0 }')"
  if [ "$count" -eq 0 ]; then
    note "nothing in the prod account looked like monitoring/ resources - no monitoring report written"
    return 0
  fi

  local dir="$REPO_ROOT/$MONITORING_DIR/discovery" run="$REPO_ROOT/$MONITORING_DIR/discovery/runs/$TIMESTAMP"
  mkdir -p "$run" "$dir/imports"
  awk -F'\t' '$3 == "monitoring"' "$src" > "$run/inventory.tsv"
  write_findings "$run/inventory.tsv" > "$run/findings.tsv"

  SUM_LABEL="MONITORING stack (prod account)"
  SUM_PROFILE="$PROD_PROFILE"
  SUM_ACCOUNT="$CUR_ACCOUNT"
  SUM_ARN="$CUR_ARN"
  SUM_REGIONS="$PROD_REGIONS"
  SUM_DURATION="$PROD_DURATION"
  SUM_SERVICES="$SERVICE_FILTER"
  SUM_SOURCE="Extracted from the prod-account scan - rows tagged \`Stack=monitoring\` or named after the observability components (grafana, prometheus, loki, tempo, alloy). The raw JSON for the whole account is in \`prod/discovery/runs/$TIMESTAMP/raw/\`."
  SUM_API_NOTE="account-wide figures - see \`prod/discovery/runs/$TIMESTAMP/\` for the call log"
  write_summary "$run/inventory.tsv" "$dir"
  stable_outputs "$run/inventory.tsv" "$dir"
  write_meta "monitoring" "$run" "$PROD_DURATION" "$PROD_REGIONS"
  prune_runs "$dir"

  ok "$count monitoring resource(s) -> ${MONITORING_DIR}/discovery/"
  MON_TSV="$run/inventory.tsv"
}

# =============================================================================
# COMBINED DEV vs PROD VIEW
# =============================================================================

write_combined() {
  local dir="$REPO_ROOT/$COMBINED_DIR"
  mkdir -p "$dir"

  local all="" dev_age="" prod_age=""
  if [ -n "${DEV_TSV:-}" ] && [ -s "$DEV_TSV" ]; then
    all="$DEV_TSV"
    dev_age="this run"
  elif [ -s "$REPO_ROOT/$DEV_DIR/discovery/inventory.tsv" ]; then
    awk 'NR > 1' "$REPO_ROOT/$DEV_DIR/discovery/inventory.tsv" > "$dir/.dev.tsv"
    all="$dir/.dev.tsv"
    dev_age="an EARLIER scan ($(date -r "$REPO_ROOT/$DEV_DIR/discovery/inventory.tsv" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown))"
  fi
  if [ -n "${PROD_TSV:-}" ] && [ -s "$PROD_TSV" ]; then
    all="${all:+$all }$PROD_TSV"
    prod_age="this run"
  elif [ -s "$REPO_ROOT/$PROD_DIR/discovery/inventory.tsv" ]; then
    awk 'NR > 1' "$REPO_ROOT/$PROD_DIR/discovery/inventory.tsv" > "$dir/.prod.tsv"
    all="${all:+$all }$dir/.prod.tsv"
    prod_age="an EARLIER scan ($(date -r "$REPO_ROOT/$PROD_DIR/discovery/inventory.tsv" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown))"
  fi

  if [ -z "$all" ]; then
    warn "no inventory to combine - run a scan first"
    return 0
  fi

  # shellcheck disable=SC2086  (deliberate word splitting: a list of file names)
  cat $all > "$dir/inventory-all.tsv"
  { printf '%s\n' "$INVENTORY_HEADER"; cat "$dir/inventory-all.tsv"; } | tsv_to_csv > "$dir/inventory-all.csv"

  local headline services
  headline="$(awk -F'\t' '
    { env = $1; tot[env]++; m[env, $11]++ }
    END {
      printf "| | DEV | PROD | Total |\n| --- | --- | --- | --- |\n"
      printf "| Resources found | %d | %d | %d |\n", tot["dev"] + 0, tot["prod"] + 0, tot["dev"] + tot["prod"]
      printf "| Managed by this repo (`ManagedBy=terraform`) | %d | %d | %d |\n", m["dev", "yes"] + 0, m["prod", "yes"] + 0, m["dev", "yes"] + m["prod", "yes"]
      printf "| **Import candidates** | **%d** | **%d** | **%d** |\n", m["dev", "no"] + 0, m["prod", "no"] + 0, m["dev", "no"] + m["prod", "no"]
      printf "| Not decidable from tags (untaggable types) | %d | %d | %d |\n", m["dev", "unknown"] + 0, m["prod", "unknown"] + 0, m["dev", "unknown"] + m["prod", "unknown"]
    }' "$dir/inventory-all.tsv")"

  # Sorted without gawk's asorti: the same list is walked by `sort` instead.
  services="$(awk -F'\t' '
    { tot[$1, $4]++; if ($11 == "no") cand[$1, $4]++; keys[$4] = 1 }
    END { for (k in keys) printf "%s\t%d\t%d\t%d\t%d\n", k, tot["dev", k] + 0, cand["dev", k] + 0, tot["prod", k] + 0, cand["prod", k] + 0 }' \
    "$dir/inventory-all.tsv" | sort | md_table "Service|DEV total|DEV candidates|PROD total|PROD candidates")"

  {
    printf '# AWS discovery - DEV vs PROD\n\n'
    printf 'Generated at `%s` by `scripts/aws-inventory-scan.sh`. Accounts: dev `%s`, prod `%s`.\n\n' \
      "$TIMESTAMP" "${DEV_ACCOUNT:-not scanned this run}" "${PROD_ACCOUNT:-not scanned this run}"
    printf 'DEV data is from %s; PROD data is from %s.\n\n' "${dev_age:-nothing}" "${prod_age:-nothing}"
    printf '## Headline\n\n%s\n\n' "$headline"
    printf '## Where the resources are\n\n%s\n\n' "$services"
    cat <<'COMBINED_TAIL'
## Reports

| Report | What it covers |
| --- | --- |
| `dev/discovery/SUMMARY.md` | the dev account (`agrovesto-dev`) |
| `prod/discovery/SUMMARY.md` | the prod account (`agrovesto-prod`) |
| `monitoring/discovery/SUMMARY.md` | the monitoring stack, which lives in the prod account |
| `.discovery/inventory-all.csv` | both accounts in one spreadsheet |

Each folder also holds `inventory.csv` (everything), `unmanaged.csv` (import
candidates) and `imports/imports-<stack>.tf.txt` (ready-to-paste import blocks).

Everything under `discovery/` and `.discovery/` is gitignored: the files hold account
IDs, IP addresses and internal hostnames, and this repo is public.
COMBINED_TAIL
  } > "$dir/COMBINED.md"

  rm -f "$dir/.dev.tsv" "$dir/.prod.tsv" "$dir/inventory-all.tsv"
  ok "combined dev-vs-prod view -> ${COMBINED_DIR}/COMBINED.md"
}

# =============================================================================
# SCAN ONE ACCOUNT
# =============================================================================

upper() { printf '%s' "$1" | tr '[:lower:]' '[:upper:]'; }

# selected <service-group> - honour --services
selected() {
  local filter
  [ -z "$SERVICE_FILTER" ] && return 0
  filter=",$(printf '%s' "$SERVICE_FILTER" | tr -d ' ' | tr '[:upper:]' '[:lower:]'),"
  case "$filter" in *,all,*) return 0 ;; esac
  case "$filter" in *",$1,"*) return 0 ;; esac
  return 1
}

# run_scanner <service-group> <profile> <region>
run_scanner() {
  # Local names are deliberately odd: a scanner's `read -r` loop variables are
  # not declared local, so they write into the nearest enclosing scope. Plain
  # names like `svc` or `profile` here would be overwritten mid-scan (which is
  # how the progress lines started printing empty service names).
  local sc_name="$1" sc_profile="$2" sc_region="$3" sc_before sc_after
  if ! command -v "scan_$sc_name" >/dev/null 2>&1; then
    warn "no scanner called '$sc_name' in this script - skipped"
    return 0
  fi
  sc_before=$ROWS
  "scan_$sc_name" "$sc_profile" "$sc_region" || true
  sc_after=$ROWS
  printf '  %-16s %5d resource(s)\n' "$sc_name" "$((sc_after - sc_before))" >&2
}

# scan_env <dev|prod> <profile> <stack-folder>
# Everything the scanners append to lands in $CUR_TSV, which finalize_env then
# turns into <stack-folder>/discovery/. This is the "dev env goes to the dev
# folder, prod env goes to the prod folder" rule.
scan_env() {
  local env="$1" profile="$2" stack_dir="$3"
  local start=$SECONDS

  CUR_ENV="$env"; CUR_PROFILE="$profile"; CUR_STACK_DIR="$stack_dir"
  CUR_DISCOVERY="$REPO_ROOT/$stack_dir/discovery"
  CUR_RUN="$CUR_DISCOVERY/runs/$TIMESTAMP"
  CUR_RAW="$CUR_RUN/raw"
  CUR_TSV="$CUR_RUN/inventory.tsv"
  CUR_PERM="$CUR_RUN/permissions.log"
  CUR_FAIL="$CUR_RUN/failed-calls.tsv"

  mkdir -p "$CUR_RAW" "$CUR_DISCOVERY/imports"
  : > "$CUR_TSV"; : > "$CUR_PERM"; : > "$CUR_FAIL"; : > "$CUR_RUN/api-calls.tsv"
  API_CALLS=0; API_FAILS=0; RAW_FILES=0; DETAIL_CALLS=0; ROWS=0; STATE_MATCHED=0

  header "Scanning the $(upper "$env") account - profile ${profile:-<default credentials>}"

  local ident
  if ! ident="$(aws_json "$profile" global sts get-caller-identity)"; then
    bad ""
    bad "Cannot authenticate with profile '${profile}'. Check it first:"
    bad "    aws sts get-caller-identity --profile ${profile}"
    bad "The ${env} scan was skipped; nothing was written to ${stack_dir}/discovery/."
    return 1
  fi
  CUR_ACCOUNT="$(printf '%s' "$ident" | jq -r '.Account // "unknown"')"
  CUR_ARN="$(printf '%s' "$ident" | jq -r '.Arn // "unknown"')"
  ok "account ${CUR_ACCOUNT} - ${CUR_ARN}"

  local regions
  if [ "$SCAN_ALL_REGIONS" = "yes" ]; then
    regions="$(aws_json "$profile" "$PRIMARY_REGION" ec2 describe-regions \
      | jq -r '.Regions[]?.RegionName' 2>/dev/null | sort | tr '\n' ' ')"
    [ -n "$regions" ] || regions="$PRIMARY_REGION"
    note "scanning every enabled region: $regions"
  else
    regions="$PRIMARY_REGION"
    note "region: $regions   (--all-regions scans every enabled region)"
  fi

  local svc region
  say ""
  info "Global services (account wide - scanned once, not per region)"
  for svc in $GLOBAL_SCANNERS; do
    selected "$svc" || continue
    run_scanner "$svc" "$profile" "global"
  done

  for region in $regions; do
    say ""
    info "Region $region"
    for svc in $REGIONAL_SCANNERS; do
      selected "$svc" || continue
      run_scanner "$svc" "$profile" "$region"
    done
  done

  local duration=$((SECONDS - start))
  API_CALLS="$(awk 'END { print NR + 0 }' "$CUR_RUN/api-calls.tsv" 2>/dev/null || printf '0')"
  API_FAILS="$(awk 'END { print NR + 0 }' "$CUR_FAIL" 2>/dev/null || printf '0')"
  RAW_FILES="$(ls -1 "$CUR_RAW" 2>/dev/null | wc -l | tr -d ' ')"
  say ""
  ok "$(upper "$env"): $ROWS resources found in ${duration}s ($API_CALLS API calls, $API_FAILS failed)"
  finalize_env "$env" "$stack_dir" "$duration" "$regions"

  # Hand the inventory back to main for the combined report.
  LAST_ENV_TSV="$CUR_TSV"
  LAST_ENV_ACCOUNT="$CUR_ACCOUNT"
  LAST_ENV_DURATION="$duration"
  LAST_ENV_REGIONS="$regions"
  return 0
}

# =============================================================================
# MAIN
# =============================================================================

SCAN_FAILED=0
DEV_TSV=""; PROD_TSV=""; MON_TSV=""
DEV_ACCOUNT=""; PROD_ACCOUNT=""
DEV_REGIONS=""; PROD_REGIONS=""
DEV_DURATION=0; PROD_DURATION=0
LAST_ENV_TSV=""; LAST_ENV_ACCOUNT=""; LAST_ENV_DURATION=0; LAST_ENV_REGIONS=""
SCAN_START=$SECONDS

cat >&2 <<'BANNER'

  ╔═══════════════════════════════════════════════════════════════════════╗
  ║   AGROVESTO - AWS DISCOVERY SCAN                                      ║
  ║   what exists in each account, and what this repo does not manage yet  ║
  ║   read only: describe-*, list-*, get-* - nothing is created or changed ║
  ╚═══════════════════════════════════════════════════════════════════════╝

BANNER

say "${C_CYAN}Configuration${C_NC}"
say "  repo root     ${C_YELLOW}${REPO_ROOT}${C_NC}"
say "  dev profile   ${C_YELLOW}${DEV_PROFILE:-<default credentials>}${C_NC}   -> ${C_GREEN}${DEV_DIR}/discovery/${C_NC}"
say "  prod profile  ${C_YELLOW}${PROD_PROFILE:-<default credentials>}${C_NC}   -> ${C_GREEN}${PROD_DIR}/discovery/${C_NC}"
say "  region        ${C_YELLOW}${PRIMARY_REGION}${C_NC}$( [ "$SCAN_ALL_REGIONS" = "yes" ] && printf ' (plus every other enabled region)' )"
say "  services      ${C_YELLOW}${SERVICE_FILTER:-all}${C_NC}"
say "  state check   ${C_YELLOW}$([ "$WITH_STATE" = "1" ] && printf 'on' || printf 'off (--with-state to settle untaggable resources)')${C_NC}"
say "  import blocks ${C_YELLOW}$([ "$GEN_IMPORTS" = "1" ] && printf 'on' || printf 'off')${C_NC}"
say "  raw responses ${C_YELLOW}$([ "$KEEP_RAW" = "1" ] && printf 'saved' || printf 'not saved')${C_NC}"
say "  aws cli       ${C_YELLOW}${AWS_CLI_VERSION}${C_NC}"
say "  started       ${C_YELLOW}$(now_utc)${C_NC}"

# Warn about typos in --services before spending a minute on the wrong scan.
if [ -n "$SERVICE_FILTER" ]; then
  for want in $(printf '%s' "$SERVICE_FILTER" | tr ',' ' '); do
    case ",$(lower "$want")," in
      *,all,*) continue ;;
    esac
    if ! printf ' %s %s ' "$GLOBAL_SCANNERS" "$REGIONAL_SCANNERS" | grep -q " $(lower "$want") "; then
      warn "'$want' is not a known service group - it will be ignored"
    fi
  done
fi

# --- DEV ---------------------------------------------------------------------
if [ "$ENVS" = "dev" ] || [ "$ENVS" = "all" ]; then
  if scan_env dev "$DEV_PROFILE" "$DEV_DIR"; then
    DEV_TSV="$LAST_ENV_TSV"; DEV_ACCOUNT="$LAST_ENV_ACCOUNT"
    DEV_REGIONS="$LAST_ENV_REGIONS"; DEV_DURATION="$LAST_ENV_DURATION"
  else
    SCAN_FAILED=1
  fi
fi

# --- PROD (and the monitoring stack that lives in the same account) ----------
if [ "$ENVS" = "prod" ] || [ "$ENVS" = "all" ]; then
  if scan_env prod "$PROD_PROFILE" "$PROD_DIR"; then
    PROD_TSV="$LAST_ENV_TSV"; PROD_ACCOUNT="$LAST_ENV_ACCOUNT"
    PROD_REGIONS="$LAST_ENV_REGIONS"; PROD_DURATION="$LAST_ENV_DURATION"
    split_monitoring
  else
    SCAN_FAILED=1
  fi
fi

# --- COMBINED ----------------------------------------------------------------
write_combined

# --- FINAL WORD --------------------------------------------------------------
TOTAL_DURATION=$((SECONDS - SCAN_START))
rule
say ""
say "${C_GREEN}Done in ${TOTAL_DURATION}s.${C_NC} Where to look:"
say ""
for pair in "dev:$DEV_TSV" "prod:$PROD_TSV" "monitoring:$MON_TSV"; do
  stack="${pair%%:*}"; tsv="${pair#*:}"
  if [ -n "$tsv" ] && [ -s "$tsv" ]; then
    cand="$(awk -F'\t' '$11 == "no"' "$tsv" | awk 'END { print NR + 0 }')"
    tot="$(awk 'END { print NR + 0 }' "$tsv")"
    say "  ${C_YELLOW}${stack}/discovery/SUMMARY.md${C_NC}  -  ${tot} resources, ${C_GREEN}${cand} import candidate(s)${C_NC}"
  else
    say "  ${stack}/discovery/  -  not scanned this run"
  fi
done
say "  ${C_YELLOW}${COMBINED_DIR}/COMBINED.md${C_NC}  -  dev vs prod side by side"
say ""
if [ "$SCAN_FAILED" = "1" ]; then
  say ""
  bad "At least one account could not be scanned - see the message above (usually an"
  bad "expired SSO session or a missing profile). Fix it and re-run; the reports that"
  bad "were written are still valid for the accounts that did work."
fi

say ""
say "Next: open a SUMMARY.md, read the ${C_CYAN}Import candidates${C_NC} table, and follow"
say "${C_CYAN}Bringing a candidate into this repo${C_NC} at the bottom of it."
say ""

[ "$SCAN_FAILED" = "1" ] && exit 1
exit 0
