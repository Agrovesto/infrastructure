# Importing existing AWS resources into the new Terraform stacks

Source of truth: `AGROVESTO-AWS-INVENTORY-20260923` (Resource Explorer, 375 resources,
dev `353833416626` + prod `221434544570`, eu-west-1). The ARNs are kept in
`imports/inventory/*.arns`. Each resource's decision is listed in
[`INVENTORY_MAP.md`](INVENTORY_MAP.md).

Rules you gave me:

| Question | Answer → how it's done |
|---|---|
| Clash between an old resource and a new one | **Adopt**: the new address imports the old resource (`imports/<stack>/imports_adopt.tf`). Nothing gets built twice. |
| Leave anything out? | **No**: every resource Terraform can manage gets imported. The only exceptions are AWS-owned defaults and runtime objects, which *cannot* be managed (§1). |
| Bootstrap | State buckets and deploy roles already exist → `imports/bootstrap/imports.tf` |
| Observability in prod | Goes to `monitoring/` |
| Secrets | Data sources / RDS-managed secrets. No secret values in code or state (§5) |

> Nothing here has been planned against AWS yet. I had no credentials, and this sandbox
> could not download Terraform, so every file was only parse-checked. The first
> `terraform plan` in each stack is the real test. Follow the phases in order and
> **apply only when the plan shows no `destroy` and no `-/+`.**

---

## 1. What happens to the 375 resources

| Decision | dev | prod | Meaning |
|---|---:|---:|---|
| **ADOPT** | 4 | 3 | Becomes an address the new code already declares (VPC, IGW, Amplify onboarding app+branch; prod VPC, IGW, RDS `migration-prod`). More adopt slots (subnets, route tables, default SG, dev host/EIP, RDS subnet group/SG) are commented out until `discover.sh` supplies the IDs. |
| **BOOTSTRAP** | 1 | 1 | `nomaos-tfstate-*` buckets → `bootstrap/` |
| **IMPORT** | 64 | 85 | Standalone resource the new design doesn't model → `legacy_*` address. Terraform generates the config (`-generate-config-out`). |
| **CONFIRM** | 28 | 36 | Importable, but first needs one fact from `discover.sh` (key-pair name, whether a KMS key is customer-managed, DMS endpoint identifier, whether an SG is the default one, subnet→slot mapping). The block is emitted **commented out**. |
| **STACK** | 4 | 6 | Belongs to a CloudFormation stack that Terraform manages as a whole (`CDKToolkit`, `Infra-ECS-Cluster-agrovesto-dev`, `agrovesto-infra-pipeline`). Importing the child as well would give it two owners. |
| **SKIP** | 64 | 79 | Can't or shouldn't be managed as its own resource:<br>• 62 security-group *rules*: captured by their parent SG import<br>• 20 service-managed ENIs<br>• RDS/EBS snapshots and retained backups<br>• AWS default option/parameter groups, MemoryDB/ElastiCache default users, X-Ray/Athena/EventBridge/App Runner defaults, default DHCP options<br>• Lambda `$LATEST`, SSM sessions and managed-instance records<br>• the RDS-owned `rds!db-…` secret<br>• the `agrovesto-infra-deployment*` CDK stacks, which are decoupled in §0 |

Import blocks are kept under `imports/` and are **not committed inside the stacks**.
`imports/stage.sh <stack>` copies them in as `zz_import_*.tf` (git-ignored), so the
CI `terraform test` suites never see them. `stage.sh --unstage <stack>` removes them
after the apply.

## 2. Code changes made so the adopted resources fit the new design

* **prod/rds.tf**
  * `random_password` + `aws_secretsmanager_secret(_version).mssql_master` → `manage_master_user_password = true`. RDS owns and rotates the password, so it never appears in plan or state. `migration-prod` already works this way (its `rds!db-…` secret is in the inventory), so importing it changes nothing about credentials.
  * New vars: `mssql_identifier`, `mssql_storage_type`, `mssql_subnet_group_name`, so the resource can take the existing instance's identifier, storage type and subnet group. All three are ForceNew if they don't match.
* **prod/ecs.tf, db_size_alarm.tf, data.tf, outputs.tf** now read the RDS-managed secret ARN (`aws_db_instance.mssql.master_user_secret[0].secret_arn`). The execution role gets `kms:Decrypt` via Secrets Manager.
* **monitoring/**
  * New `data "aws_db_instance" "mssql"` (`mssql_instance_identifier = "migration-prod"`) supplies the host, port and managed secret ARN.
  * `mssql_metrics.py` takes `DB_HOST`/`DB_PORT` from the environment, because RDS-managed secrets hold only `username`/`password`.
  * The IAM policy is scoped to that one secret ARN.
* **Tests** were updated for the new credential model (`prod/tests/rds.tftest.hcl`, `monitoring/tests/monitoring.tftest.hcl`). Static coverage: dev 84.3 %, prod 71.4 %, monitoring 97.8 %, all above the CI gates.

> ⚠️ Anything outside this repo that read `agrovesto-prod-mssql-master` must switch to
> the RDS-managed secret. The legacy `nomaosDBcredentials` / `agxDBcredentials`
> secrets are imported as metadata only and stay as they are.

---

## Phase 0: before anything (both accounts)

1. **Freeze manual changes** in both accounts for the import window.
2. **Back up.** Take a manual RDS snapshot of `migration-prod`, and make sure versioning is on for both state buckets.
3. **Decouple the old CDK app `agrovesto-infra-deployment`** (and its nested
   `…RotationSingleUser…` stacks) in both accounts. Its resources get imported one
   by one, and a resource can't be owned by CloudFormation *and* Terraform at the
   same time.
   * In the CDK app, set `removalPolicy: RETAIN` on every resource (or add `DeletionPolicy: Retain` to the synthesized template) and deploy.
   * Then `aws cloudformation delete-stack` each stack. The resources stay in place; only the stack record goes away.
   * The CDK code for the `nomaos`/`agx` DB instances includes a `CustomVpcRestrictDefault` custom resource. Retaining it is fine; its Lambda is imported as `legacy_*`.
4. **Keep** `CDKToolkit`, `Infra-ECS-Cluster-agrovesto-dev` and `agrovesto-infra-pipeline`. Terraform imports each as an `aws_cloudformation_stack`, which brings their children under Terraform.

## Phase 1: discover (read-only)

```bash
imports/discover.sh dev     # uses AWS_PROFILE=agrovesto-dev
imports/discover.sh prod    # uses AWS_PROFILE=agrovesto-prod
```

This writes `imports/discovery-<env>.txt` (git-ignored). It contains:
* VPC CIDR and AZ order
* each subnet's CIDR, AZ and route (public/private)
* default SGs and NACLs
* instance AMI/type/key; which volumes are ROOT volumes
* EIP associations and key-pair names
* KMS key manager (AWS vs CUSTOMER)
* the full RDS parameters
* DMS endpoint identifiers, ACM domains, Amplify apps, the bootstrap bucket/role state
* IAM, Route53, ALB and EFS resources that Resource Explorer did not index

**Send me the two discovery files** (they contain no secrets) and I'll fill in every
commented slot and tfvar in §4. You can also do it yourself by following §4.

## Phase 2: bootstrap (once per account, local state)

```bash
imports/stage.sh bootstrap && cd bootstrap && terraform init
# prod
AWS_PROFILE=agrovesto-prod terraform plan  -state=prod.tfstate -var account_id=221434544570
AWS_PROFILE=agrovesto-prod terraform apply -state=prod.tfstate -var account_id=221434544570
# dev (bootstrap defaults are prod-flavoured - override)
AWS_PROFILE=agrovesto-dev terraform plan -state=dev.tfstate -var account_id=353833416626 \
  -var environment=dev -var deploy_role_name=<dev role from discover.sh>
```

What to expect in the plan:
* The bucket policy / lifecycle get **created** if they didn't exist.
* `aws_iam_role.deploy` gets **updated in place**: its trust policy moves to the patterns in `github_sub_patterns`. Check that those patterns match the branches CI deploys from (`dev`, `main`) **before applying**, or CI loses access.

Afterwards, upload the local state so it isn't lost:
`aws s3 cp prod.tfstate s3://nomaos-tfstate-221434544570-eu-west-1/bootstrap/terraform.tfstate`
(and the same for dev). Then `imports/stage.sh --unstage bootstrap`.

## Phase 3: the stacks: prod → monitoring → dev

Monitoring reads the prod VPC/ALB by tag, so prod must be applied first.

```bash
imports/stage.sh prod
cd prod && terraform init
terraform plan -generate-config-out=generated_legacy.tf -out=tfplan | tee plan.txt
```

1. **`generated_legacy.tf`** holds the resource blocks Terraform wrote for the `legacy_*` imports. Clean it up and rename it to `legacy.tf` (commit that file):
   * Delete computed/conflicting arguments that the plan flags as errors, for example `aws_instance` `ipv6_address_count` next to `ipv6_addresses`, or `aws_launch_template` defaults.
   * **Lambda** (`legacy_*` functions): add
     `lifecycle { ignore_changes = [filename, source_code_hash, s3_key] }` and a placeholder `filename`. The function code stays where it is, and CodePipeline/CDK keep deploying it.
   * **aws_instance**: add `lifecycle { ignore_changes = [user_data, ami] }` so the plan never recreates a host.
   * **aws_amplify_app**: add `lifecycle { ignore_changes = [access_token, oauth_token, basic_auth_credentials] }`.
   * **aws_ssm_parameter**: if a parameter is `SecureString`, *don't import it*. Read it with `data "aws_ssm_parameter"` instead (§5).
2. Read `plan.txt`. It should show only:
   * `… will be imported`, and
   * in-place `~` updates to tags (`ManagedBy = terraform`), plus the deny-all default SG change.

   **Stop and fix** if you see any `-/+`/`destroy`. It almost always means a tfvar in `terraform.auto.tfvars` doesn't match the real resource (see §4).
3. Once the plan is clean: `terraform apply tfplan`, then `imports/stage.sh --unstage prod`, and commit `prod/legacy.tf`.
4. Run `terraform plan` again. It must show **no changes**.

Repeat for `monitoring` (only 10 prod log groups and CloudWatch-agent SSM objects are imported there) and then `dev`.

## 4. Adoption checklist: making the plan show *import*, not *replace*

### 4.1 Network (dev and prod)
| New-code input | Set it to (from discover.sh) | Why |
|---|---|---|
| `vpc_cidr` | the adopted VPC's CIDR | `cidr_block` is ForceNew; a mismatch would destroy the VPC |
| `public_subnet_cidrs` (+ `private_`, `database_` in prod) | CIDRs of the existing subnets, in the **order of the AZ list** discover.sh prints | subnet `cidr_block` and `availability_zone` are ForceNew |
| `aws_default_security_group.default` slot | the VPC's `default` SG | the new code strips its rules (deny-all); check nothing depends on them |

**Prod topology.** The existing VPC has 4 subnets. The new design has 2 public, 2 private and 2 database subnets, plus a NAT.
* Match existing subnets to slots by route: IGW → public, NAT/none → private.
* The code creates any slots left over. Choose CIDRs for them that don't overlap the existing ones.
* Existing subnets that match no slot stay as `legacy_*` imports (they're `CONFIRM` in `imports_legacy.tf`).

### 4.2 RDS: `migration-prod` → `aws_db_instance.mssql`
Put the discovered values in `prod/terraform.auto.tfvars`:
```hcl
mssql_identifier               = "migration-prod"
mssql_engine                   = "<Engine>"            # ForceNew
mssql_engine_version           = "<EngineVersion>"     # never downgrade
mssql_instance_class           = "<DBInstanceClass>"
mssql_allocated_storage_gb     = <AllocatedStorage>    # can't shrink
mssql_max_allocated_storage_gb = <MaxAllocatedStorage>
mssql_storage_type             = "<StorageType>"
mssql_port                     = <Port>                # ForceNew
mssql_master_username          = "<MasterUsername>"    # ForceNew
mssql_subnet_group_name        = "<DBSubnetGroupName>"
mssql_multi_az                 = <MultiAZ>
```
Then uncomment the subnet group and SG slots in `imports/prod/imports_adopt.tf`.

The code hard-codes `storage_encrypted = true` (ForceNew). **If discover.sh shows
`StorageEncrypted=False`, stop and tell me.** An unencrypted instance can only
become encrypted through snapshot → encrypted copy → restore. That's a planned
maintenance window, not an import.

Also check:
* **Backup and maintenance windows**: the code sets `03:00-04:00` and `sun:04:30-sun:05:30`. These change in place with `apply_immediately = false`, so they take effect in the next maintenance window.
* **Performance Insights**: Express edition doesn't support it. If the plan errors on it, tell me and I'll make it a variable.

### 4.3 Dev host (optional)
To keep `i-00af32231113d64f9` as `aws_instance.app`:
* set `ami_id`, `instance_type` and `key_name` to its values, and uncomment the instance/EIP slots
* expect an in-place user_data update, which causes a stop/start

Otherwise it's imported as `legacy_*`, and the new host is created next to it when you're ready.

### 4.4 Things the new code creates that already exist but aren't in the inventory
Resource Explorer doesn't index IAM roles, Route53 zones or records, and some other
types. If discover.sh lists any of these, they need an adopt block too, or the apply
will fail with "already exists":
* a hosted zone for `nomaos.com` / `agrovesto.com`
* a role named `agrovesto-prod-*`
* an ALB

**Send me the discovery output** and I'll add them.

## 5. Secrets: how they're handled

| Secret | Handling |
|---|---|
| Prod DB master (`migration-prod`) | RDS-managed (`manage_master_user_password`). Terraform only references the ARN; ECS reads the value at runtime. |
| `nomaosDBcredentials`, `agxDBcredentials` (both accounts) | `aws_secretsmanager_secret` **metadata** only; there's deliberately no `_secret_version`, so no value in state. Rotation Lambdas are imported with `ignore_changes` on code. |
| `rds!db-…` | Owned by RDS; not imported (SKIP). |
| SSM SecureString params | Read with `data "aws_ssm_parameter"` or referenced by ARN in ECS `secrets`; never imported. |
| Grafana admin (monitoring) | Unchanged: `random_password` → SSM SecureString. That value *is* in the monitoring state. The state buckets are private, encrypted and versioned. |
| Dev `mssql_sa_password`, `logging.grafana_admin_password` | Unchanged; pass them via `TF_VAR_*` in CI. |

## 6. Done means

* `terraform plan` shows **No changes** in bootstrap (both accounts), prod, monitoring and dev.
* `imports/stage.sh --unstage` has been run for every stack (no `zz_import_*.tf` left).
* `<stack>/legacy.tf` is committed.
* Every row in `INVENTORY_MAP.md` is ADOPT/IMPORT/BOOTSTRAP/STACK in state, or SKIP with its reason.
