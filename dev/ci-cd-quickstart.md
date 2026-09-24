# CI/CD Quickstart (dev)

The dev stack is a **flat module in `dev/`**: Terraform code, `.tftpl`
templates and scan configs all live in that folder. There is no
`environments/dev` directory and no `modules/` directory; the sibling `prod/`
folder holds the (separate) production stack.

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
| 3. Apply | `terraform-apply` | push to `dev` | AWS OIDC + vars |

All `terraform` commands run from the **`dev/` folder**
(`TF_WORKING_DIR: "dev"`), i.e. right next to `versions.tf`, `variables.tf`,
`locals.tf`, … There is no `cd environments/dev` step anywhere.

The `terraform-plan` and `terraform-apply` jobs begin with a
**Verify Terraform Root Module** step that fails fast if `versions.tf`,
`variables.tf`, `locals.tf`, `outputs.tf` or any of the three `.tftpl`
templates is missing, so a bad merge can't turn into a confusing
"no configuration files" Terraform error.

---

## 2. Prerequisites (repo secrets)

The runner talks to AWS via OIDC (no long-lived keys).

| Secret | Required | Used for |
| --- | --- | --- |
| `AWS_ROLE_ARN_DEV` | Yes (plan/apply) | Role to assume via `configure-aws-credentials` |
| `TF_VAR_MSSQL_SA_PASSWORD_DEV` | Yes (plan/apply) | MSSQL SA password (marked `sensitive` in code) |
| `DEV_GRAFANA_GITHUB_CLIENT_ID` / `DEV_GRAFANA_GITHUB_CLIENT_SECRET` | No | Supplying both enables GitHub OAuth in dev Grafana |
| `SONARQUBE_GITHUB_CLIENT_ID` / `SONARQUBE_GITHUB_CLIENT_SECRET` / `SONARQUBE_GITHUB_APP_ID` / `SONARQUBE_GITHUB_PRIVATE_KEY` | No | Supplying all four enables the SonarQube GitHub App login and HTTPS edge |

OAuth callback URLs, app permissions and the required CIDR/DNS setup are in
[`../docs/github-sso.md`](../docs/github-sso.md).

> GitHub won't let you read an existing secret back. To set/add one:
> **Settings → Secrets and variables → Actions**, then **New repository secret**.


**AWS OIDC** also needs the repo's GitHub OIDC provider configured in AWS and a
role with a trust policy scoped to this repo + environment; its ARN is what you
store in `AWS_ROLE_ARN_DEV`. The provider's audience is `sts.amazonaws.com` (already
set in the workflow). A starting point for the trust policy is
`trust-policy.json` in this directory.

---

## 3. Terraform input variables

The configuration declares several **required** variables
(`domain_name`, `amplify_apps`, `apis`, `mssql_databases`, `mssql_sa_password`)
that have no default. `terraform plan` in CI will fail until these are supplied
to the runner.

The non-secret ones are committed in **`terraform.auto.tfvars`** at the repo
root. Terraform auto-loads any `*.auto.tfvars` file next to the root module, so
CI needs no extra flags; just keep secrets out of it.

Two options for anything not in that file:

1. **Environment variables** prefixed `TF_VAR_` (what the workflow already does
   for the SA password). e.g. for `domain_name`:
   `TF_VAR_domain_name=agrovesto.dev`.
2. A committed per-env **`*.auto.tfvars`** file holding only non-secret values.

Locally, an (untracked) `terraform.tfvars` still takes precedence over
`*.auto.tfvars`, so you can override anything without touching git.

---

## 4. Verify end-to-end

Open a draft PR that touches a `.tf` file and confirm you see the
**Terraform Plan** comment (from `terraform-plan`).

---

## 5. Migrating an existing state file (flattening)

Dropping `environments/dev` + `modules/*` changes every resource address. A
state file created with the old layout must be moved before the next `plan`,
otherwise Terraform will try to **destroy and recreate the whole stack**.

Back up the state first (`terraform state pull > backup.tfstate`), then run
`terraform state mv` for each resource you have:

```bash
# example
terraform state mv module.vpc.aws_vpc.this              aws_vpc.main
terraform state mv module.ec2.aws_instance.this         aws_instance.app
terraform state mv module.backup.aws_s3_bucket.this     aws_s3_bucket.backup
```

| Old address (in `environments/dev`) | New address (root) |
| --- | --- |
| `module.vpc.aws_vpc.this` | `aws_vpc.main` |
| `module.vpc.aws_internet_gateway.this` | `aws_internet_gateway.main` |
| `module.vpc.aws_subnet.public[N]` | `aws_subnet.public[N]` |
| `module.vpc.aws_route_table.public` | `aws_route_table.public` |
| `module.vpc.aws_route.internet` | `aws_route.internet` |
| `module.vpc.aws_route_table_association.public[N]` | `aws_route_table_association.public[N]` |
| `module.security_groups.aws_security_group.ec2` | `aws_security_group.ec2` |
| `module.backup.aws_s3_bucket.this` | `aws_s3_bucket.backup` |
| `module.backup.aws_s3_bucket_public_access_block.this` | `aws_s3_bucket_public_access_block.backup` |
| `module.backup.aws_s3_bucket_versioning.this` | `aws_s3_bucket_versioning.backup` |
| `module.backup.aws_s3_bucket_server_side_encryption_configuration.this` | `aws_s3_bucket_server_side_encryption_configuration.backup` |
| `module.backup.aws_s3_bucket_lifecycle_configuration.this` | `aws_s3_bucket_lifecycle_configuration.backup` |
| `module.iam.aws_iam_role.ec2` | `aws_iam_role.ec2` |
| `module.iam.aws_iam_role_policy.ec2` | `aws_iam_role_policy.ec2` |
| `module.iam.aws_iam_role_policy_attachment.ssm` | `aws_iam_role_policy_attachment.ssm` |
| `module.iam.aws_iam_instance_profile.ec2` | `aws_iam_instance_profile.ec2` |
| `module.iam.aws_iam_role.scheduler` | `aws_iam_role.scheduler` |
| `module.iam.aws_iam_role_policy.scheduler` | `aws_iam_role_policy.scheduler` |
| `module.ec2.aws_instance.this` | `aws_instance.app` |
| `module.ec2.aws_ebs_volume.mssql` | `aws_ebs_volume.mssql` |
| `module.ec2.aws_volume_attachment.mssql` | `aws_volume_attachment.mssql` |
| `module.ec2.aws_eip.this[0]` | `aws_eip.app[0]` |
| `module.ec2.aws_eip_association.this[0]` | `aws_eip_association.app[0]` |
| `module.scheduler.aws_scheduler_schedule_group.this` | `aws_scheduler_schedule_group.ec2` |
| `module.scheduler.aws_scheduler_schedule.start` | `aws_scheduler_schedule.start` |
| `module.scheduler.aws_scheduler_schedule.stop` | `aws_scheduler_schedule.stop` |
| `module.amplify.aws_amplify_app.this["KEY"]` | `aws_amplify_app.this["KEY"]` |
| `module.amplify.aws_amplify_branch.this["KEY"]` | `aws_amplify_branch.this["KEY"]` |
| `module.amplify.aws_amplify_domain_association.this["KEY"]` | `aws_amplify_domain_association.this["KEY"]` |
| `module.dns.aws_route53_zone.this[0]` | `aws_route53_zone.this[0]` |
| `module.dns.aws_route53_record.a["KEY"]` | `aws_route53_record.a["KEY"]` |
| `module.dns.aws_route53_record.cname["KEY"]` | `aws_route53_record.cname["KEY"]` |
| `module.dns.aws_route53_record.alias["KEY"]` | `aws_route53_record.alias["KEY"]` |

Sanity check afterwards: `terraform plan` should show **no** destroys/creates
for existing infrastructure.

---

## 6. Troubleshooting

- **`Error: Unsupported argument` / missing required variable** → you haven't
  supplied a required input var; see §3.
- **`Missing 'versions.tf' in the Terraform root module`** → the flat layout was
  broken (or you checked out a branch that still uses `environments/dev`).
- **`Could not assume role`** → `AWS_ROLE_ARN_DEV` missing, or the OIDC trust policy
  doesn't match this repo/branch. Recheck §2.
- **`security-scan` formatting step is green but the tree isn't formatted** →
  intentional: `terraform fmt -check` is informational (`continue-on-error`)
  until a `terraform fmt` pass lands. `terraform fmt -recursive` before you
  commit.
- **Plan wants to destroy everything after the flattening** → you skipped §6.
