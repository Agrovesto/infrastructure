# Agrovesto infrastructure (dev)
<!-- CI test suite check trigger -->

Terraform for the **dev** AWS account. The stack is a **single flat module in
this `dev/` folder** — there is no `modules/` or `environments/` tree. The
repo root holds a sibling `prod/` stack (ECS/RDS/ALB) and the two workflow
files (`dev.workflow.yml`, `prod.workflow.yml`).

```
dev/
├── versions.tf              # terraform block, backend, provider
├── variables.tf             # every input (single env + what used to be modules)
├── locals.tf                # naming, nginx upstreams, rendered templates, DNS maps
├── data.tf                  # AZs, Ubuntu 24.04 LTS AMI, IAM policy documents
├── vpc.tf                   # VPC + public subnet + IGW
├── security_groups.tf       # nginx (80/443) + SSH
├── s3_backup.tf             # versioned, encrypted MSSQL backup bucket
├── iam.tf                   # EC2 host role + EventBridge scheduler role
├── ec2.tf                   # app host, MSSQL data volume, Elastic IP
├── scheduler.tf             # start 08:00 / stop 20:00 (Africa/Lagos)
├── amplify.tf               # frontends
├── route53.tf               # DNS (disabled: manage_dns=false — prod account owns the zone)
├── outputs.tf
├── terraform.auto.tfvars    # committed, secret-free values (auto-loaded)
├── user_data.sh.tftpl       # cloud-init for the EC2 host
├── docker-compose.yml.tftpl # nginx + APIs + Vault + MSSQL
├── nginx.conf.tftpl         # one server block per subdomain
├── checkov.yml  trivy.yml  trust-policy.json
└── ci-cd-quickstart.md
(../dev.workflow.yml is the CI/CD pipeline — see below)
```

## What gets created

| Piece | Details |
| --- | --- |
| Amplify | Two apps (`landing`, `onboarding`) with custom domains. Add a key in `amplify_apps` to create more. |
| VPC | Single public subnet + IGW (dev). |
| EC2 | Public subnet, Elastic IP, **nginx** reverse proxy. Root disk (OS + apps) + extra EBS (MSSQL data). |
| Docker on EC2 | 5 APIs, HashiCorp Vault (dev mode), SQL Server 2022 with 5 databases. Bind-mounted to the MSSQL disk. |
| Route 53 | **Managed from the prod account** (`manage_dns = false` here): dev hosts live under `dev.nomaos.com` (e.g. `wallet.dev.nomaos.com` → this host's EIP), created by the prod stack's `extra_a_records` / `extra_cname_records`. |
| S3 | Versioned, encrypted bucket for nightly MSSQL backups (cron on the instance). |
| EventBridge Scheduler | Start EC2 07:00, stop 20:00 every day (`Africa/Lagos`). |

Traffic path:

```
Internet → Route53 (zone owned by the PROD account)
            ├─ landing.dev / onboarding.dev  → Amplify
            └─ wallet.dev / onboarding-api.dev / input.dev / moneval.dev / serviceprovider.dev / vault.dev / mssql.dev
                                 → EIP → nginx (EC2) → docker containers
```

## Adding more resources later

- **Another frontend** — add an entry under `amplify_apps` in `terraform.auto.tfvars`.
- **Another API** — add an entry under `apis` (`image`, `host_port`, `subdomain`). Nginx + DNS follow automatically.
- **Another MSSQL database** — append to `mssql_databases`.
- **Extra DNS records** — use `extra_a_records`, `extra_cname_records` or `extra_alias_records` in `locals.tf`; they merge over the generated ones.
- **Another environment** — see the sibling `prod/` module (ECS/Fargate + RDS +
  ALB). For yet another account, copy `prod/` and change `project`,
  `environment`, `vpc_cidr` and the backend `key`.

## Apply (dev)

Run from this folder:

```bash
cd dev
cp terraform.tfvars.example terraform.tfvars   # optional local overrides
# edit domain, GitHub token, SA password, real API images
terraform init
terraform plan
terraform apply
```

DNS does not come from this stack: the prod account owns the zone. After a dev
apply, hand the `ec2_public_ip` and `frontend_default_domains` outputs to the
prod stack's `extra_a_records` / `extra_cname_records` (see
`prod/terraform.auto.tfvars`) so the `*.dev.nomaos.com` records point here —
then apply prod.

MSSQL SA password must meet SQL Server complexity rules. Vault root token in **dev** is `dev-root-token` (change via user-data / compose when you leave dev-mode).

## CI/CD (`dev.workflow.yml`)

The pipeline is authored at the repository root as **`dev.workflow.yml`** and
runs every Terraform command from this folder (`TF_WORKING_DIR: "dev"`).

- **Pull requests** (to `dev`): Checkov + Trivy scans (SARIF → code scanning)
  and a read-only `terraform plan` posted as a PR comment.
- **Push to `dev`**: applies the dev stack after the same checks.
- The runner needs AWS OIDC (`AWS_ROLE_ARN_DEV` secret). Non-secret required
  variables (`domain_name`, `amplify_apps`, `apis`, `mssql_databases`, …) are
  supplied by the committed `terraform.auto.tfvars`; the MSSQL SA password is
  injected via the `TF_VAR_MSSQL_SA_PASSWORD_DEV` secret.

Install it into GitHub Actions with:

```bash
cp dev.workflow.yml .github/workflows/dev.yml
```

> Heads-up: the checked-in `.github/workflows/dev.yml` still points at the old
> flat-repository layout and is now stale — replace it with
> `dev.workflow.yml` (the automation token has no `workflows` permission, so
> it cannot be updated by CI itself).

See `ci-cd-quickstart.md` for the full pipeline walkthrough
(secrets, variables, troubleshooting).

## Notes

- APIs listen on the docker network; nginx is the only public HTTP/S listener.
- Scheduler IAM can start/stop **any** instance in the account (`ec2:StartInstances` on `*`). Tighten the resource ARN if you add prod later.
- Amplify custom domains require the hosted zone in this account, so they stay off (`amplify_enable_custom_domain = false`); prod publishes the frontend CNAMEs instead (`landing.dev.nomaos.com` → Amplify default domain).
- Resource addresses changed when the tree was flattened (e.g. `aws_instance.app`
  instead of `module.ec2.aws_instance.this`). If you had a pre-existing state
  file, run `terraform state mv` (or import) before the first apply — see the
  migration table in `ci-cd-and-costs-quickstart.md`.
