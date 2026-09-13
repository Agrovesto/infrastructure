# Terraform native tests (`terraform test`)

One suite per environment. They run **offline** — `mock_provider "aws"` means no
credentials, no API calls and no state, so they are safe to run from a laptop
or CI without touching the real accounts.

```bash
terraform -chdir=dev  init -backend=false
terraform -chdir=dev  test

terraform -chdir=prod init -backend=false
terraform -chdir=prod test
```

(`init` is still needed once, to install providers — the mock provider reuses
the real AWS provider schema. `-backend=false` keeps the S3 state backend out
of it; tests never read or write real state.)

Requires Terraform **>= 1.7** (`mock_provider` and `override_data`). Both
`versions.tf` files now pin `required_version = ">= 1.7.0"`.

## Layout

```
prod/tests/
  vpc.tftest.hcl              VPC, subnets, routing, NAT, flow logs
  acm.tftest.hcl              certificate + DNS validation records
  compute.tftest.hcl          ECS cluster, task defs, services, IAM, logs
  rds.tftest.hcl              SQL Server instance, secrets, db-init toggle
  alb.tftest.hcl              load balancer, listeners, routing, log bucket
  ecr.tftest.hcl              repositories + lifecycle policies
  dns.tftest.hcl              zones, service aliases, extra records
  vault.tftest.hcl            KMS, EFS, Vault service + on/off toggle
  security_groups.tftest.hcl  ALB / ECS / RDS / EFS rules

dev/tests/
  ec2.tftest.hcl              app host, volumes, Elastic IP
  platform.tftest.hcl         VPC, scheduler, backups, ECR, Amplify, DNS
```

## What they actually protect

Three of these are regression tests for bugs that broke `plan`, `apply` **and**
`import` on this stack. Terraform evaluates the whole configuration before it
touches AWS, so a bad `count`/`for_each` fails everything:

| Test | Guards against |
|---|---|
| `vpc.tftest.hcl` → `routing_counts_are_known_at_plan_time` | `count = length(aws_subnet.private)` → "Invalid count argument" |
| `vpc.tftest.hcl` → `single_nat_gateway_mode` / `per_az_nat_gateway_mode` | NAT topology drifting from `var.single_nat_gateway` |
| `acm.tftest.hcl` → `validation_records` | `for_each` over certificate attributes → "Invalid for_each argument" |
| `vault.tftest.hcl` → `kms_and_efs` | `count = length(aws_subnet.private)` on the EFS mount targets |
| `dev/tests/platform.tftest.hcl` → `vpc` | `count = length(aws_subnet.public)` on the route table association |

The rest pin the things that are easy to break silently: encryption, retention,
deletion protection, tag conventions, security-group scoping, and the
enable/disable toggles (`enable_vault`, `run_db_init`, `manage_dns`,
`single_az_ecs`, `associate_elastic_ip`, `amplify_enable_custom_domain`).

## Notes

- Assertions avoid values that are only known after apply (ARNs, endpoints,
  DNS names). Two runs in `prod/tests/compute.tftest.hcl` use
  `command = apply` because they inspect the rendered `container_definitions`
  JSON, which embeds the Secrets Manager ARN.
- `ingress`/`egress` on `aws_security_group` and `condition`/`action` on
  `aws_lb_listener_rule` are **sets**, which Terraform cannot index — every
  assertion iterates or flattens instead.
- Each test file sets the variables it needs, so the suites do not depend on
  `terraform.auto.tfvars` staying in sync.
