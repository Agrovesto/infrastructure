# 🔎 AWS discovery scan — finding resources that are not in Terraform yet

`scripts/aws-inventory-scan.sh` walks both AWS accounts, lists everything that
exists, works out which of it this repo already manages, and writes the result
**into the folder of the environment it came from**:

| Scanned with | Written to |
| :--- | :--- |
| `agrovesto-dev` profile (dev account) | `dev/discovery/` |
| `agrovesto-prod` profile (prod account) | `prod/discovery/` |
| prod-account resources that belong to the monitoring stack | `monitoring/discovery/` |
| both accounts side by side | `.discovery/` (repo root) |

The monitoring stack lives in the prod account (`monitoring/versions.tf` points at
the prod state bucket), so a prod scan is split in two: everything lands in
`prod/discovery/`, and the rows carrying `Stack=monitoring` — or named after
Grafana, Prometheus, Loki, Tempo, Alloy — are summarised again in
`monitoring/discovery/`.

---

## Quick start

```bash
# both accounts, eu-west-1 only (the default) — about a minute
./scripts/aws-inventory-scan.sh

# one account
./scripts/aws-inventory-scan.sh --env dev
./scripts/aws-inventory-scan.sh --env prod

# every enabled region instead of just eu-west-1
./scripts/aws-inventory-scan.sh --all-regions

# a quick look at two services
./scripts/aws-inventory-scan.sh --services ec2,s3

# settle the untaggable resources (Route53 records etc.) against real state
./scripts/aws-inventory-scan.sh --with-state
```

Needs `aws` (v2, authenticated with both profiles), `jq`, and the usual
`awk`/`sort`/`find`. `terraform` is only needed for `--with-state`.

**Read only.** The script makes `describe-*`, `list-*` and `get-*` calls and
nothing else. No resource is created, modified or deleted, and secret *values*
are never read — Secrets Manager and SSM are listed by name. The AWS managed
policy `ReadOnlyAccess` is enough; anything the role cannot read is recorded in
`runs/<timestamp>/failed-calls.tsv` and skipped instead of aborting the scan.

---

## Reading the output

Start at `dev/discovery/SUMMARY.md` (or `prod/…`). Sections, in order:

1. **Headline** — how many resources were found, how many already carry
   `ManagedBy=terraform`, how many are candidates, how many API calls failed.
2. **Import candidates by target stack** — how many rows point at `dev/`,
   `prod/`, `monitoring/`, and which import file to open.
3. **Resources by service** — one line per service/kind with the
   managed / candidate / unknown split.
4. **Import candidates** — the actual list: name, ID, Terraform resource type
   and the import ID to use.
5. **Cannot be decided from tags** — resource types that AWS will not let you
   tag (Route53 records above all). These are *not* counted as candidates,
   because guessing would drown the report: `prod/route53.tf` owns the whole
   `nomaos.com` zone, including every `dev-*` record. Re-run with
   `--with-state` to settle them.
6. **Findings worth acting on** — cost (unattached volumes, idle Elastic IPs,
   stopped instances, log groups with no retention), security (security groups
   open to the world, unencrypted buckets and volumes, IAM users who never
   signed in, no CloudTrail/GuardDuty) and hygiene (unversioned buckets, ECR
   repos that are `MUTABLE` in prod or have no lifecycle policy, single-AZ or
   `db.t3.micro` RDS, ACM certificates stuck in `PENDING_VALIDATION`).
7. **API calls that failed** — usually a missing read permission. A failed call
   means *not scanned*, not *empty*; the difference matters.

Other files:

| File | What it is |
| :--- | :--- |
| `inventory.csv` | everything found, one row per resource — opens in Excel/Sheets |
| `inventory.tsv` | the same, tab separated (what the report is built from) |
| `unmanaged.csv` | candidates only |
| `unverifiable.tsv` | the `managed = unknown` rows |
| `imports/imports-<stack>.tf.txt` | ready-to-paste `import` blocks |
| `runs/<timestamp>/raw/*.json` | the raw response of every successful call |
| `runs/<timestamp>/meta.json` | account, profile, regions, duration, call counts |
| `runs/<timestamp>/findings.tsv` | the findings table, machine readable |
| `runs/<timestamp>/api-calls.tsv` | every call the script made, with exit code |
| `runs/<timestamp>/permissions.log` | AWS CLI's own error text for the failures |

The four files at the top of `discovery/` always describe the **latest** run;
timestamped runs are kept underneath (`--keep-runs`, default 5, then pruned).

---

## How "already managed" is decided

Every stack sets provider `default_tags`:

```hcl
# dev/versions.tf, prod/versions.tf, monitoring/versions.tf
default_tags {
  tags = {
    Project     = var.project      # agrovesto
    Environment = var.environment  # dev | prod
    ManagedBy   = "terraform"
  }
}
```

and `monitoring/locals.tf` adds `Stack = "monitoring"`. So a resource carrying
`ManagedBy=terraform` was created by this repo, and one without it was created
some other way — console, CLI, another tool, an older stack. That second group
is what the report calls an **import candidate**.

A candidate is not automatically something to adopt. Most hand-made resources
are better deleted than imported; adopting one means writing and maintaining its
config forever. The report lists them so the decision can be made deliberately.

Some list APIs return no tags at all (`events list-rules`,
`cloudwatch describe-alarms`, `servicediscovery list-*`, `iam list-policies`,
`kms describe-key`, `ec2 describe-flow-logs`, `logs describe-log-groups`). For
those the script makes one extra tag call per resource, capped by
`MAX_DETAIL_CALLS`, rather than reading an empty tag set as "unmanaged" — which
would have flagged every EventBridge rule and alarm in the account.

---

## Bringing a candidate into the repo

`imports/imports-<stack>.tf.txt` contains Terraform ≥ 1.5 `import` blocks, one
per candidate:

```hcl
# s3/bucket agrovesto-manual-exports  [region eu-west-1, status public-access-not-blocked]
#   encryption=none|versioning=Disabled|public_access=partially-blocked|lifecycle=no
import {
  to = aws_s3_bucket.discovered_agrovesto_manual_exports
  id = "agrovesto-manual-exports"
}
```

The file extension is `.tf.txt` on purpose. `dev/discovery/` sits **inside** the
`dev` root module, so a real `.tf` file there would be loaded by every local
`terraform plan -chdir=dev` — and by CI — and each of them would try to import
the whole account.

The procedure:

1. **Decide.** For each candidate: adopt, or delete? Delete the blocks you do
   not want.
2. **Pick the stack.** `dev/` for the dev account, `prod/` for prod,
   `monitoring/` for the observability stack that lives in the prod account.
3. **Copy** what is left into `<stack>/imports.tf` (drop the `.txt`).
4. **Let Terraform write the config:**

   ```bash
   terraform -chdir=<stack> init
   terraform -chdir=<stack> plan -generate-config-out=generated.tf
   ```

   `generated.tf` holds the real, live configuration of each imported resource —
   far more reliable than writing it from the report.
5. **Tidy.** Move the generated resources into the file where they belong
   (`ec2.tf`, `s3.tf`, `security_groups.tf`, …), swap hard-coded values for the
   existing `var.*` / `local.*` conventions, add them to `terraform.auto.tfvars`
   if they are driven by a map, and **delete the import blocks** — they are
   one-shot, and leaving them behind makes the next plan fail once the resource
   is in state.
6. **Prove nothing will change.** `terraform -chdir=<stack> plan` must report
   `0 to add, 0 to change, 0 to destroy`. Any diff means the config does not
   match reality: fix the config, never let an import plan destroy something
   live.
7. **Let CI check it.** `./scripts/run_test_suite.sh <stack>` runs
   `terraform test` plus the coverage gate (dev 60%, prod 70%, monitoring 95%),
   and the pipeline adds Checkov, Trivy, Sonar and Infracost. Newly adopted
   resources usually need a case in `<stack>/tests/` to keep coverage up, and
   Checkov will now judge them — expect to fix findings or add a documented
   suppression in `<stack>/checkov.yml`.

Import ID formats in the generated file follow the common case from the AWS
provider docs. A few are fiddlier (ECS task definitions, EventBridge Scheduler
entries with a non-default schedule group, resources addressed by ARN versus
name) — the provider page for that resource type is the authority:
<https://registry.terraform.io/providers/hashicorp/aws/latest/docs>.

---

## `--with-state`: settling the untaggable ones

Tags decide most rows, but Route53 records, IAM instance profiles, SSM
parameters and a handful of other types cannot be tagged, so they come out as
`unknown`. With `--with-state` the script also runs

```bash
AWS_PROFILE=<profile> terraform -chdir=<stack> show -json
```

for each stack (`dev`, plus `prod` and `monitoring` when scanning prod), pulls
every string out of the state, and marks a discovered resource `managed = yes`
when its ID or import ID appears there. Needs `terraform` on PATH and an
initialised stack (`.terraform/` present); if either is missing it warns and
carries on with tags alone. It never writes to state.

---

## Gitignore

`dev/discovery/`, `prod/discovery/`, `monitoring/discovery/` and `.discovery/`
are ignored: the output contains account IDs, ARNs, IP addresses and internal
hostnames, and this repo is public. To keep one curated snapshot in git anyway:

```bash
git add -f dev/discovery/SUMMARY.md
```

---

## What this replaced

The earlier `aws-complete-scan.sh` covered Route53, S3, EC2, RDS, SNS and
Lambda, wrote everything to the current directory in one timestamped blob, and
had a few problems that made its numbers unreliable:

- it printed progress to **stdout** and then captured stdout to get the output
  directory back, so `DEV_SCAN` held 200 lines of log and every
  `cat "$DEV_SCAN/SUMMARY.md"` after it silently failed;
- `encryption=$(aws s3api get-bucket-encryption … && echo Yes || echo No)` put
  the whole JSON response *and* the word `Yes` into one variable;
- `set -e` meant the first denied API call aborted the entire scan;
- counts were re-read from a temp file with `grep … || echo 0` inside a
  pipeline, which reported 0 rather than the real number on a miss;
- and the closing heredoc was quoted (`<< 'EOF'`), so the report ended with the
  literal text `$DEV_SCAN` instead of a path.

This version keeps the same idea — one command, both accounts — and adds:
per-environment folders, ~30 more services, tag-based managed/unmanaged
detection, stack attribution (dev / prod / monitoring), cost, security and
hygiene findings, generated `import` blocks, an optional state cross-check, raw
JSON per call for writing config by hand, and a record of every call that
failed so "not scanned" is never mistaken for "does not exist".

## Importing from an AWS Resource Explorer report

`scripts/aws-inventory-scan.sh` needs AWS credentials. When all you have is an
inventory somebody else exported - an AWS Resource Explorer 2 search, the
console's bulk ARN copy, a spreadsheet - use this instead:

```bash
./scripts/import-from-inventory.py --report inventory.md          # markdown table of ARNs
./scripts/import-from-inventory.py --arns dev=dev.txt --arns prod=prod.txt
```

It maps each ARN's account id to an environment through the repo's own backend
blocks (nothing is hard coded), so dev-account rows are written to
`dev/discovery/` and prod-account rows to `prod/discovery/`, and every resource
lands in one of five buckets: **A** import now, **B** one command decides the
address, **C** base network (can force a replacement), **D** a decision rather
than a discovery, **X** excluded - AWS-owned default, CDK/CloudFormation owns
it, it is a child of something else (ENIs, security-group rules, `$LATEST`
versions), it is a backup artifact, or it is already in state.

Output per environment: `discovery/imports/imports-<env>.tf.txt` (only section A
uncommented; B/C/D carry the exact command that settles them),
`discovery/TRIAGE.md` (the write-up, committed) and
`discovery/inventory-<date>.csv` (every row with its bucket, local only).

A Resource Explorer report carries ARNs and nothing else - no names, no tags - so
it cannot prove who owns a security group, a KMS key or an Amplify app. That is
why sections B-D exist instead of guesses. For ownership evidence, run
`scripts/aws-inventory-scan.sh`, which reads tags.
