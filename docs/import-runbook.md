# Import runbook (hybrid)

**Imported:** only the existing resources the new design uses. Terraform **creates** everything else. **Legacy** resources stay unmanaged and are deleted by hand after cut-over (§5).

Order: **bootstrap → prod → monitoring → dev**. Region is `eu-west-1`. Prod and monitoring share one state key and are separated by workspace: prod uses `default`, monitoring uses `monitoring`.

| Stack | Imported (`<stack>/imports.tf`) |
|---|---|
| bootstrap | state bucket (and its versioning, SSE, public-access block, lifecycle, policy), GitHub OIDC provider, deploy role and policy |
| prod | VPC, IGW, 2 public + 2 database subnets, route tables and routes, zones `nomaos.com` / `agrovesto.com`, RDS `migration-prod` and its subnet group |
| monitoring | nothing: all resources are new |
| dev | VPC, IGW, default SG, public subnet and route table, Amplify apps `onboarding` / `landing` and their branches |

**Rule for every apply: the plan shows 0 to destroy and nothing "must be replaced".** Delete `imports.tf` once a stack plans with "No changes".

## 1. Bootstrap (local state, per account)

```bash
cd bootstrap && terraform init
AWS_PROFILE=agrovesto-prod terraform plan  -state=prod.tfstate -var-file=prod.tfvars -out=prod.tfplan
AWS_PROFILE=agrovesto-prod terraform apply -state=prod.tfstate prod.tfplan
AWS_PROFILE=agrovesto-dev  terraform plan  -state=dev.tfstate  -var-file=dev.tfvars  -out=dev.tfplan
AWS_PROFILE=agrovesto-dev  terraform apply -state=dev.tfstate  dev.tfplan
```

Before the dev plan:
- Run `aws iam list-attached-role-policies --role-name nomaos-dev-github-terraform`.
- Set `deploy_admin_access` and `import_deploy_policy` in `dev.tfvars` to match.

The dev trust policy is rewritten to the `github_sub_patterns` in `dev.tfvars`.

## 2. Prod

```bash
cd prod && terraform init && terraform workspace select default
AWS_PROFILE=agrovesto-prod terraform plan -out=tfplan
```

Expect **18 to import**, the new design resources to add, and **0 to destroy**. The only changes to live resources:
- **RDS** (applied at the next maintenance window):
  - backup retention 2 → 30 days
  - deletion protection on
  - final snapshot on delete
  - the new RDS SG added next to the 2 existing SGs
- **Route tables:** `public[1]` moves to the shared public route table.
- tags

The ECS tasks read the DB login from the existing `nomaosDBcredentials` secret. Check that it has `username` and `password` keys:

```bash
aws secretsmanager get-secret-value --secret-id nomaosDBcredentials \
  --query SecretString --output text --profile agrovesto-prod | jq 'keys'
```

`manage_master_user_password` stays off, because turning it on would rotate the live password.

Apply, re-plan until "No changes", then delete `prod/imports.tf`.

## 3. Monitoring (after prod is applied)

```bash
cd monitoring && terraform init && terraform workspace select -or-create monitoring
AWS_PROFILE=agrovesto-prod terraform plan -out=tfplan
```

The monitoring plan only adds resources. The lookups for the prod VPC, ALB and ALB security group succeed once prod has been applied.

If the plan offers to **destroy Route 53 zones**, you are in the wrong workspace. Stop.

## 4. Dev

```bash
cd dev && terraform init
export TF_VAR_mssql_sa_password='<SA password for the new dev host>'
AWS_PROFILE=agrovesto-dev terraform plan -out=tfplan
```

Apply, re-plan until "No changes", then delete `dev/imports.tf`.

## 5. After cut-over: legacy resources (unmanaged, delete by hand)

**Prod:**
- CodePipelines, CodeBuild and CodeStar/CodeConnections
- CDK/CloudFormation stacks `agrovesto-infra-pipeline` and `CDKToolkit`:
  - delete the stacks rather than their resources, so CloudFormation cleans up after itself
- old Amplify apps
- DMS endpoints and subnet group:
  - `agxdb2instance` points at a deleted secret
- rotation Lambdas and the old DB secrets:
  - keep `nomaosDBcredentials`, because the ECS tasks read it
- old EC2 `noma-agx`, its launch templates, key pairs and EIP
- old SGs, route table `rtb-0614…`, the old ACM `*.nomaos.com` cert, SNS topics, SES identities, codepipeline/CFN S3 buckets, and old log groups

**Dev:**
- the old host `new-noma-api` (`i-00af32231113d64f9`):
  - migrate its data first
  - move EIP `eipalloc-0b7f04c0906f47a4e` to the new host before deleting it
- old Amplify apps, AppRunner/CodeConnections, CFN stacks, ECR, the customer KMS key, the old SGs, subnets and buckets

**Both accounts:**
- role `nomaos-bootstrap-dev-deploy`

**Check before deleting anything that holds data:** S3 buckets (`agrovesto-storage`), EBS volumes, secrets.

**Other follow-ups:**
- `migration-prod` is unencrypted. Plan a window: snapshot → encrypted copy → restore → swap. Then set `mssql_storage_encrypted = true`.
- The prod default SG `sg-05a2722a…` still has live rules. Move them to named SGs, then set `manage_default_security_group = true`.
- Dev and prod both use `172.96.0.0/16`. Re-IP one of them before any peering.

## Rekognition and dev Alertmanager (created fresh, nothing to import)

- `rekognition.tf` in dev and prod creates: the `<stack>-customers` face collection, the media bucket `<stack>-rekognition-<account>` (`uploads/` expires after 90 days, `liveness/` after 30), a video job-status topic that feeds an SQS queue with a DLQ, the video role and a Cognito guest pool for Face Liveness. Apps read `terraform output rekognition`.
- Start* video calls pass `NotificationChannel = { SNSTopicArn = video_sns_topic_arn, RoleArn = video_role_arn }`.
- Dev Alertmanager publishes to the dev alerts topic. Config is synced from S3 at boot. After changing rules, run `aws s3 sync` on the host, or reboot it.
