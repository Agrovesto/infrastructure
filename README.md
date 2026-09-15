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
├── monitoring/              # prod account — open-source observability stack (Prometheus, Loki,
│   │                        # Tempo, Grafana, Alloy, blackbox, pushgateway, cost + RDS jobs)
│   ├── *.tf, terraform.auto.tfvars
│   ├── checkov.yml  trivy.yml  README.md
│   ├── dashboards/          # Grafana dashboards provisioned through SSM + EFS
│   ├── scripts/             # budget_report.py, mssql_metrics.py
│   └── tests/               # terraform test suites (mock_provider, no AWS calls)
├── dev.workflow.yml         # dev CI/CD pipeline — copy into .github/workflows/dev.yml
├── prod.workflow.yml        # prod CI/CD pipeline — copy into .github/workflows/prod.yml
├── monitoring.workflow.yml  # monitoring CI/CD pipeline — copy into .github/workflows/monitoring.yml
├── sonar-project-dev.properties         # SonarQube scope for the dev pipeline
├── sonar-project-prod.properties        # SonarQube scope for the prod pipeline
├── sonar-project-monitoring.properties  # SonarQube scope for the monitoring pipeline
├── scripts/
│   └── tf_coverage.py       # Terraform resource coverage — see tests/README.md
├── tests/
│   └── README.md            # the terraform test suites in dev/tests, prod/tests and monitoring/tests
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
| `monitoring/` | prod | Open-source observability for the prod stack: Prometheus, Alertmanager, Loki, Tempo, Grafana OSS, Alloy (OTLP + Loki push), blackbox uptime probes and Pushgateway on Fargate, a Cost and Usage Report + DuckDB budget job, and an hourly SQL Server DMV metrics job. No CloudWatch alarms/dashboards, Container Insights, X-Ray, Performance Insights, RDS enhanced monitoring or AWS Budgets — see `monitoring/README.md` | `monitoring.workflow.yml` → applies on push to `main` |

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

> **Merging a change to `*.workflow.yml` does not change CI.** GitHub Actions
> runs the files under `.github/workflows/`, and the token that manages this
> repo has no `workflows` permission — pushes touching those paths are rejected
> outright. Every pipeline change therefore has to be installed by hand, by
> someone whose credentials do have that permission.

The automation token that manages this repo has **no `workflows` permission**,
so the pipelines live at the repository root as canonical copies and are
installed into `.github/workflows/` by hand:

```bash
cp dev.workflow.yml        .github/workflows/dev.yml         # repoints dev CI at ./dev
cp prod.workflow.yml       .github/workflows/prod.yml        # deploys ./prod to the prod account
cp monitoring.workflow.yml .github/workflows/monitoring.yml  # deploys ./monitoring to the prod account
git add .github/workflows && git commit -m "ci: install pipelines" && git push
```

- **Dev workflow** triggers on PRs/pushes to the `dev` branch that touch
  `dev/**`; Terraform runs with `TF_WORKING_DIR=dev`; assumes the role in the
  `AWS_ROLE_ARN_DEV` secret (dev account).
- **Prod workflow** triggers on PRs/pushes to the `main` branch that touch
  `prod/**`; Terraform runs with `TF_WORKING_DIR=prod`; assumes the role in
  the `AWS_ROLE_ARN_PROD` secret (prod account — see `prod/trust-policy.json`
  for the OIDC trust-policy template and `prod/README.md` for one-time setup).

- **Monitoring workflow** triggers on PRs/pushes to the `main` branch that
  touch `monitoring/**`; Terraform runs with `TF_WORKING_DIR=monitoring`;
  assumes the role in the `AWS_ROLE_ARN_PROD` secret (the stack lives in the
  prod account). Resource coverage is gated at 95%.

> The currently installed `.github/workflows/dev.yml` still targets the old
> flat layout; replace it as above after merging this change. The monitoring
> pipeline has never been installed, so `monitoring/**` currently has no CI.

### Pipeline stages

All three pipelines run the same stages against their own directory, and every
step is blocking — there is no `continue-on-error` anywhere, and Checkov runs
without `soft_fail` (its findings are cleared through the per-folder
`checkov.yml` skip lists, not by letting the job fail softly).

| Stage | Job | What it does |
|---|---|---|
| 1 | `Lint & Security Scan` | `terraform fmt -check -recursive`, Checkov, Trivy (vuln + secret + misconfig) → job summary |
| 2 | `Terraform Test & Coverage` | `terraform test` + resource coverage, gated on `TF_COVERAGE_FAIL_UNDER` (dev 60, prod 70, monitoring 95) |
| 3 | `SonarQube Analysis` | SonarScanner against `sonar-project-<env>.properties` |
| 4 | `Terraform Plan & PR Diff` | plan on PRs, posted as a PR comment |
| 5 | `Infracost Cost Estimate` | PR-only cost diff of the folder, opt-in through `INFRACOST_API_KEY` (skipped, with a warning, while the secret is unset) |
| 6 | `Terraform Apply` | plan + apply on push to `dev` / `main` |

Stages 2 and 3 gate 4 and 5 — a failing suite or a coverage regression stops
the plan and the apply, not just the build badge.

**Terraform version.** `TF_VERSION` must satisfy `required_version` in
`dev/versions.tf` and `prod/versions.tf` (`>= 1.7.0`, needed for
`mock_provider`). Terraform enforces that during `init`, before it does
anything else, so a lower pin fails every run at *Terraform Init* with
*Unsupported Terraform Core version*. It is currently `1.10.5`.

**SonarQube** is opt-in and skipped (with a warning, not a failure) until these
secrets exist:

| Secret | Required | Notes |
|---|---|---|
| `SONAR_TOKEN` | yes | Needs the *Execute Analysis* permission on the project |
| `SONAR_HOST_URL` | self-hosted only | e.g. `https://sonar.example.com`; leave unset for SonarCloud |

Each folder reports as its own SonarQube project
(`agrovesto-infrastructure-dev` / `-prod` / `-monitoring`), scoped to `dev/`,
`prod/` and `monitoring/` respectively — see the `sonar-project-*.properties`
files.

## Local runs

```bash
cd dev   # or: cd prod
terraform init && terraform plan
```

## Cost estimates

Every stack in this repository is priced by one Infracost config, so the whole
repo can be costed locally with a single command (needs the Infracost CLI and a
free API key; no AWS credentials):

```bash
./scripts/infracost.sh
```

It runs `infracost.yml` (bootstrap, dev, prod, monitoring), prints the
per-project table and then adds the costs Infracost cannot price — scheduled
Fargate tasks, Cloud Map, in-use public IPv4 addresses, internet egress — from
`infracost-extras.json`, for one combined monthly figure. Usage assumptions live
in `infracost-usage/*.yml`; the method, the extras ledger and the per-resource
reasoning are in `docs/infracost.md`.
