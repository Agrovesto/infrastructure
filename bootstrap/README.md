# Prod bootstrap (run once)

Creates everything the prod pipeline needs **before it can deploy anything**:

| Creates | Used by |
| --- | --- |
| S3 bucket `nomaos-tfstate-<prod-account-id>-eu-west-1` (versioned, AES256, public-access-blocked, TLS-only, 30-day noncurrent expiry) | `prod/versions.tf` `backend "s3"` |
| GitHub Actions OIDC provider (`token.actions.githubusercontent.com`, live thumbprints) | both workflows' `configure-aws-credentials` |
| Deploy role `agrovesto-prod-github-deploy` (trust: `main`, PRs, `arena/*` branches — see `github_sub_patterns`) | the `AWS_PROD_ROLE_ARN` secret in `prod.workflow.yml` |

It is **not part of any pipeline**: plain local state (`*.tfstate` is
gitignored), run manually from a workstation with admin access to the prod
account. `dev/` and `prod/` workflows never plan or scan this folder.

## Run it

```bash
# credentials: an admin identity in the PROD account, e.g. an SSO profile
aws sso login --profile prod-admin

cd bootstrap
terraform init
terraform plan
AWS_PROFILE=prod-admin terraform apply
```

The apply prints a `next_steps` block; in short:

```bash
# 1) fill the real bucket/account into the prod backend
sed -i 's/PROD_ACCOUNT_ID/<prod-account-id>/' ../prod/versions.tf

# 2) save the deploy role ARN as the prod pipeline's secret
gh secret set AWS_PROD_ROLE_ARN --body "<deploy-role-arn-from-output>"

# 3) install the prod workflow (the token that manages this repo can't) and merge to main
cp ../prod.workflow.yml ../.github/workflows/prod.yml
```

After the merge to `main`, the prod workflow itself runs
`terraform init/validate/plan/apply` in `../prod` using that role and bucket.

## Choices

- **`deploy_admin_access = true`** — attach `AdministratorAccess` to the deploy
  role instead of the default scoped policy. The default policy already lists
  every service the prod stack manages (`ec2/ecs/ecr/elbv2/rds/route53/acm/s3/
  secretsmanager/logs/kms/efs/iam/sts`) with `*:*`, so admin is mostly for
  convenience; a permissions boundary is the proper way to cap either later.
- **`create_oidc_provider = false`** — if the provider already exists in the
  prod account (or `terraform import aws_iam_openid_connect_provider.github
  arn:aws:iam::<acct>:oidc-provider/token.actions.githubusercontent.com`).
- **`github_sub_patterns`** — repo `sub` claims allowed to assume the role.
  Defaults match the existing `prod/trust-policy.json` pattern
  (`repo:Agrovesto@101108012/*`, main + PRs + arena branches). Tighten to just
  `.../infrastructure:...` once the dust settles.

## Notes

- **State locking**: like the dev backend, the S3 backend here has no DynamoDB
  lock table (Terraform 1.6 doesn't support S3-native `use_lockfile`). CI
  concurrency groups (`github.workflow`-`github.ref`) already serialise runs;
  add a lock table later if you apply from multiple places.
- **Local state**: the bootstrap's own `terraform.tfstate` stays on the
  machine that ran it (gitignored). Keep a copy somewhere safe — or later move
  it into the bucket it created (`terraform init -migrate-state` with a
  `backend "s3"` block added in `versions.tf`).
- **Pure-CLI alternative** (no Terraform): the same three resources can be
  created with the AWS CLI/Console — create the bucket with versioning +
  default encryption + public access block, add the OIDC provider from
  `token.actions.githubusercontent.com` (audience `sts.amazonaws.com`), and
  create the role with the trust policy in `../prod/trust-policy.json`
  (replace `PROD_ACCOUNT_ID`) plus permissions. The Terraform path above is
  the documented one because it can't drift.

## Teardown

Only for full environment rebuilds: the bucket must be emptied first
(`aws s3 rm s3://<bucket> --recursive` then delete versions) and any in-use
dev/prod must be destroyed before `terraform destroy` removes the role.
