# Agrovesto infrastructure (dev)

Reusable Terraform modules for the **dev** AWS account.

```
modules/          # reusable building blocks
environments/dev  # composition for this account only
```

## What gets created

| Piece | Details |
| --- | --- |
| Amplify | Two apps (`landing`, `onboarding`) with custom domains. Add a key in `amplify_apps` to create more. |
| VPC | Single public subnet + IGW (dev). |
| EC2 | Public subnet, Elastic IP, **nginx** reverse proxy. Root disk (OS + apps) + extra EBS (MSSQL data). |
| Docker on EC2 | 5 APIs, HashiCorp Vault (dev mode), SQL Server 2022 with 5 databases. Bind-mounted to the MSSQL disk. |
| Route 53 | Hosted zone + A records for every backend/vault hostname → EC2 EIP. Amplify manages frontend CNAMEs via domain association. |
| S3 | Versioned, encrypted bucket for nightly MSSQL backups (cron on the instance). |
| EventBridge Scheduler | Start EC2 weekdays 08:00, stop 20:00 (`Africa/Lagos`). |

Traffic path:

```
Internet → Route53
            ├─ www / onboarding  → Amplify
            └─ auth / api / payments / notify / analytics / vault / mssql
                                 → EIP → nginx (EC2) → docker containers
```

## Adding more resources later

- **Another frontend** — add an entry under `amplify_apps` in `terraform.tfvars`.
- **Another API** — add an entry under `apis` (`image`, `host_port`, `subdomain`). Nginx + DNS follow automatically.
- **Another MSSQL database** — append to `mssql_databases`.
- **Another environment** — copy `environments/dev` and change names/CIDRs.

## Apply (dev)

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
# edit domain, GitHub token, SA password, real API images
terraform init
terraform plan
terraform apply
```

Delegate `domain_name` to the `route53_name_servers` output at your registrar.

MSSQL SA password must meet SQL Server complexity rules. Vault root token in **dev** is `dev-root-token` (change via user-data / compose when you leave dev-mode).

## CI/CD (`.github/workflows/dev.yml`)

All Terraform commands in the pipeline run from `environments/dev`.

- **Pull requests** (to `main`, `dev`, `devops`): Checkov + Trivy scans (SARIF
  → code scanning) and a read-only `terraform plan` are posted as a PR comment.
- **Push to `dev`**: applies the dev environment after the same checks.
- The runner needs AWS OIDC (`AWS_ROLE_ARN` secret). Non-secret required
  variables (`domain_name`, `amplify_apps`, `apis`, `mssql_databases`, …) must
  be supplied to the runner as a `terraform.tfvars`; the MSSQL SA password is
  injected via the `TF_VAR_MSSQL_SA_PASSWORD` secret. See the
  `terraform.tfvars.example` for the full list of variables.

## Notes

- APIs listen on the docker network; nginx is the only public HTTP/S listener.
- Scheduler IAM can start/stop **any** instance in the account (`ec2:StartInstances` on `*`). Tighten the resource ARN if you add prod later.
- Amplify custom domains require the hosted zone to exist in the same account (this stack creates it by default).
