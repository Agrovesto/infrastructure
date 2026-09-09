# CI/CD & Infracost Quickstart (dev)

This repo ships its Terraform CI/CD pipeline as a **root-level copy** —
`dev.workflow.yml` — because the automation token used to manage the repo has
no `workflows` permission and therefore cannot commit into `.github/workflows`.
Install it locally with:

```bash
cp dev.workflow.yml .github/workflows/dev.yml
```

Everything below assumes the workflow is installed as
`.github/workflows/dev.yml`.

---

## 1. What the workflow does

| Stage | Job | When | Needs |
| --- | --- | --- | --- |
| 1. Lint & security | `security-scan` | PR + push (`.tf`/`.tfvars`/`.tftpl`/scan-configs changed) | none |
| 2. Terraform plan | `terraform-plan` | pull requests | AWS OIDC + vars |
| 3. Cost estimate | `infracost` | pull requests | AWS OIDC + vars + `INFRACOST_API_KEY` |
| 4. Apply | `terraform-apply` | push to `dev` | AWS OIDC + vars |

All `terraform`/`infracost` commands run from `environments/dev`.

---

## 2. Prerequisites (repo secrets)

The runner talks to AWS via OIDC (no long-lived keys) and to Infracost via an
API key.

| Secret | Required | Used for |
| --- | --- | --- |
| `AWS_ROLE_ARN` | Yes (plan/apply/infracost) | Role to assume via `configure-aws-credentials` |
| `TF_VAR_MSSQL_SA_PASSWORD` | Yes (plan/apply) | MSSQL SA password (marked `sensitive` in code) |
| `INFRACOST_API_KEY` | Only for cost estimates | Runs the `infracost` job; skip → job is skipped |

> GitHub won't let you read an existing secret back. To set/add one:
> **Settings → Secrets and variables → Actions**, then **New repository secret**.
>
> To get an Infracost API key:
> `infracost auth login` once locally (or https://www.infracost.io/docs/#quick-start),
> then `infracost configure get api_key`.

**AWS OIDC** also needs the repo's GitHub OIDC provider configured in AWS and a
role with a trust policy scoped to this repo + environment; its ARN is what you
store in `AWS_ROLE_ARN`. The provider's audience is `sts.amazonaws.com` (already
set in the workflow).

---

## 3. Terraform input variables

The Terraform module declares several **required** variables
(`domain_name`, `amplify_apps`, `apis`, `mssql_databases`, `mssql_sa_password`)
that have no default. `terraform plan` in CI will fail until these are supplied
to the runner. Because `terraform.tfvars` is gitignored, provide them in the
runner environment. Two clean options:

1. **Environment variables** prefixed `TF_VAR_` (what the workflow already does
   for the SA password). e.g. for `domain_name`:
   `TF_VAR_domain_name=agrovesto.dev`.
2. A committed per-env **`*.auto.tfvars`** file (e.g.
   `environments/dev/terraform.auto.tfvars`) holding only non-secret values;
   Terraform reads `*.auto.tfvars` automatically. Keep secrets out of it.

Use whichever matches how you already run `terraform apply` locally.

---

## 4. Infracost & the usage file

`environments/dev/infracost-usage.yml` holds the *consumption* assumptions
Infracost can't infer from code (an EC2 scheduler runtime and S3 backup
storage). The workflow passes `--usage-file` automatically when the file exists
next to `environments/dev`.

Run it locally to preview before relying on it:

```bash
# from the repo root
export INFRACOST_API_KEY=...
cd environments/dev
infracost breakdown --path=. --usage-file=infracost-usage.yml --format=table
```

### Common usage-file edits
- **EC2 scheduler**: `module.ec2.aws_instance.this.monthly_hrs` is the big one.
  The dev host runs ~08:00–20:00 on weekdays (≈260 h/mo) because of the
  EventBridge scheduler. Set to `730` if you ever run it 24/7.
- **Backup bucket**: `module.backup.aws_s3_bucket.this.standard.storage_gb`
  reflects nightly MSSQL backups retained 14 days. Adjust to real backup size.
- EIP & route53 record costs are not usage-file driven — see comments in the
  usage file and the README "cost recommendations".

### Get an accurate usage file from live usage (optional)
If you run Infracost somewhere with AWS access, it can scaffold a usage file
with placeholders, which you then fill in:

```bash
cd environments/dev
infracost breakdown --path=. --sync-usage-file --usage-file=infracost-usage.yml
```

---

## 5. Verify end-to-end

Open a draft PR that touches a `.tf` file and confirm you see, as separate
comments:

1. **Terraform Plan** (from `terraform-plan`), and
2. **Infracost monthly cost diff** (from `infracost`, only if the
   `INFRACOST_API_KEY` secret is set).

If the `infracost` job is skipped because the key is missing, that's expected —
add the key and re-run.

---

## 6. Troubleshooting

- **`Error: Unsupported argument` / missing required variable** → you haven't
  supplied a required input var; see §3.
- **`Could not assume role`** → `AWS_ROLE_ARN` missing, or the OIDC trust policy
  doesn't match this repo/branch. Recheck §2.
- **Infracost shows `-` for usage-based rows** → no usage-file value matched;
  confirm the resource address key and file path (§4).
- **`security-scan` formatting step is green but the tree isn't formatted** →
  intentional: `terraform fmt -check` is informational (`continue-on-error`)
  until a `terraform fmt` pass lands. `terraform fmt -recursive` before you
  commit.
