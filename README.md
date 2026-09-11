# Agrovesto infrastructure

Terraform for the Agrovesto AWS accounts. The repository holds **one folder per
environment**; each folder is a self-contained, flat Terraform root module.

```
.
├── dev/                     # dev account — EC2 + docker (nginx, 5 APIs, Vault, MSSQL on EC2)
│   ├── *.tf, *.tftpl, terraform.auto.tfvars
│   ├── checkov.yml  trivy.yml  trust-policy.json
│   └── README.md  ci-cd-quickstart.md
├── prod/                    # prod account — ECS/Fargate + ECR + ALB + RDS SQL Server + Route53
│   ├── *.tf, terraform.auto.tfvars
│   ├── checkov.yml  trivy.yml  trust-policy.json
│   └── README.md
├── dev.workflow.yml         # dev CI/CD pipeline — copy into .github/workflows/dev.yml
├── prod.workflow.yml        # prod CI/CD pipeline — copy into .github/workflows/prod.yml
├── bootstrap/               # run-once (manual, local state): prod tfstate S3 bucket,
│   │                        # GitHub OIDC provider + Terraform deploy role -> AWS_ROLE_ARN_PROD
│   └── README.md
└── .github/workflows/       # installed workflows (managed manually, see below)
```

## Environments

| Folder | Account | What it creates | Workflow |
| --- | --- | --- | --- |
| `dev/` | dev | Amplify frontends, single public EC2 running nginx + docker (5 APIs, Vault, SQL Server 2022 with 5 databases), S3 backups, EventBridge start/stop scheduler. **No DNS** — see below | `dev.workflow.yml` → applies on push to `dev` |
| `prod/` | prod | VPC with public + private/db subnets and NAT, internet-facing ALB (HTTPS, ACM wildcard), 5 ECS Fargate services **+ HashiCorp Vault** in private subnets (**single-AZ for now**), 5 ECR repos, RDS SQL Server (single-AZ for now) with the same 5 databases, **all of Route53**: the hosted zone + prod aliases + dev records | `prod.workflow.yml` → applies on push to `main` |

Service names and database names are identical in both accounts (dev naming
convention): `wallet`, `onboarding`, `input`, `moneval`, `serviceprovider`.

**DNS is owned by the prod account.** The prod stack creates the zone and all
records; prod services serve the apex subdomains and dev is served under
`dev.nomaos.com` (the dev stack creates no Route53 resources itself).

| Service | Dev URL (plan) | Prod URL |
| --- | --- | --- |
| wallet | wallet.dev.nomaos.com | wallet.nomaos.com |
| onboarding | onboarding-api.dev.nomaos.com | onboarding-api.nomaos.com |
| input | input.dev.nomaos.com | input.nomaos.com |
| moneval | moneval.dev.nomaos.com | moneval.nomaos.com |
| serviceprovider | serviceprovider.dev.nomaos.com | serviceprovider.nomaos.com |

Dev's DNS records (dev EC2 Elastic IP, Amplify domains) are variables of the
prod stack — see the `extra_a_records` / `extra_cname_records` blocks in
`prod/terraform.auto.tfvars` — so flipping dev infrastructure only ever
requires a prod apply, from the prod account. Cutover order: apply prod →
delegate NS at the registrar → apply dev (see `prod/README.md`).

## Bootstrapping the prod account (one-time)

The prod pipeline needs two things that can't create themselves: the Terraform
state bucket and the IAM role GitHub Actions assumes. The run-once
`bootstrap/` module creates both (plus the GitHub OIDC provider):

```bash
cd bootstrap && terraform init && AWS_PROFILE=prod-admin terraform apply
# ...then follow the printed next_steps:
#   sed -i 's/PROD_ACCOUNT_ID/<prod-acct>/' prod/versions.tf
#   gh secret set AWS_ROLE_ARN_PROD --body "<deploy-role-arn>"
```

See `bootstrap/README.md` for the full runbook (policy choices, trust
patterns, CLI alternative).

## Installing the GitHub Actions workflows

The automation token that manages this repo has **no `workflows` permission**,
so the pipelines live at the repository root as canonical copies and are
installed into `.github/workflows/` by hand:

```bash
cp dev.workflow.yml  .github/workflows/dev.yml    # repoints dev CI at ./dev
cp prod.workflow.yml .github/workflows/prod.yml   # new: deploys ./prod to the prod account
```

- **Dev workflow** triggers on PRs/pushes to the `dev` branch that touch
  `dev/**`; Terraform runs with `TF_WORKING_DIR=dev`; assumes the role in the
  `AWS_ROLE_ARN_DEV` secret (dev account).
- **Prod workflow** triggers on PRs/pushes to the `main` branch that touch
  `prod/**`; Terraform runs with `TF_WORKING_DIR=prod`; assumes the role in
  the `AWS_ROLE_ARN_PROD` secret (prod account — see `prod/trust-policy.json`
  for the OIDC trust-policy template and `prod/README.md` for one-time setup).

> The currently installed `.github/workflows/dev.yml` still targets the old
> flat layout; replace it as above after merging this change.

## Local runs

```bash
cd dev   # or: cd prod
terraform init && terraform plan
```
