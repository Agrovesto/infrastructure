# dev/ - what the AWS inventory means for this folder

Generated 2026-09-23 by `scripts/import-from-inventory.py` from the AWS Resource Explorer 2 inventory of 2026-09-23 (375 resources, eu-west-1, accounts 353833416626 + 221434544570).
Account(s): 353833416626. Region indexed: eu-west-1 only.

**165 resources indexed: 12 ready to import, 30 needing one check, 13 network, 20 decisions, 90 excluded.**

Import blocks: [`discovery/imports/imports-dev.tf.txt`](imports/imports-dev.tf.txt). Every row with its reason: `discovery/inventory-2026-09-23.csv`.

## Read this first

**90 of 165 indexed resources are excluded.** They are AWS-owned defaults (`default.memorydb-*`, `primary` Athena workgroup, the `Default` X-Ray rule), resources another tool owns (CDK/CloudFormation stacks are deployed in this account), children of a parent resource (ENIs, individual security-group rules, `$LATEST` function versions), backup artifacts (EBS/RDS snapshots), or the Resource Explorer index itself. Importing any of those either fails outright or starts a fight between two tools.

**This inventory has no names and no tags.** Resource Explorer returns ARNs, so nothing here can prove whether a security group, KMS key, Amplify app or bucket is yours, a service's, or CDK's. That is why every bucket-B row carries the single command that answers it, and why no bucket-B block is uncommented.

**Coverage is eu-west-1 only, and global services are missing.** Route 53 hosted zones and IAM identities are indexed in us-east-1, so their absence here means nothing. `scripts/aws-inventory-scan.sh` uses describe calls and sees them - run it before trusting any 'this does not exist' conclusion on this page.

**Prod-named log groups live in the dev account:** `/nomaos/prod/api`. Either an application is writing production logs into dev, or the names are stale. Worth settling before importing them, because the retention you choose then applies to whatever is actually writing there.

**An ECS cluster (`agrovesto-dev`) exists in the dev account** but `dev/` defines no ECS - it runs docker compose on one EC2 host. The cluster came from the CloudFormation stack `Infra-ECS-Cluster-agrovesto-dev-*`, i.e. CDK. Decide whether that cluster stays (CDK keeps owning it) or goes; it is not something to import.

## Does this stack exist in the account yet?

`dev/` creates resources named `agrovesto-dev-*`. Of the 14 names it would use, **none exist in this account**: `agrovesto-dev-app-host`, `agrovesto-dev-ec2`, `agrovesto-dev-ec2-sg`, `agrovesto-dev-eip`, `agrovesto-dev-host-config`, `agrovesto-dev-igw`, `agrovesto-dev-logging-data`, `agrovesto-dev-mssql-backups`, `agrovesto-dev-mssql-data`, `agrovesto-dev-onboarding` (and 4 more).

That is the most important fact on this page: **the `dev/` stack has not been applied to this account.** Most of what it defines must therefore be *created*, not imported. The resources worth importing are the ones it would otherwise duplicate - the VPC, subnets, route tables, buckets and databases that already exist - because creating a second copy of those is what costs money and causes outages.

Before any of this: `terraform -chdir=dev state list`. If it is empty, the stack has no state and every import below is a first adoption; if it is not empty, reconcile the list against section A first, because importing a resource that is already in state under a different address fails with 'resource already managed'.

## Buckets

| Bucket | Count | Meaning |
|---|---:|---|
| **A - import now** | 12 | Standalone resources nothing in the repo claims - paste and plan. |
| **B - one command decides the address** | 30 | Correct address depends on a name/domain/owner the ARN does not carry; each block has the one command that reveals it. |
| **C - base network: read the warning before touching this** | 13 | Live VPC, subnets, route tables, gateway, NACL, DHCP options. Adopting them can force a replacement if the config's CIDRs differ - verify first. |
| **D - a decision, not a discovery** | 20 | Exists, but whether Terraform should own it is a policy call (scratch resources, build artifacts, service-created log groups, compute the stack creates fresh). |
| **X - excluded** | 90 | Not importable, or importing it would be wrong: see the breakdown below. |

| Group | Count |
|---|---:|
| derived from a parent resource | 39 |
| owned by CDK / CloudFormation | 25 |
| AWS-owned default | 18 |
| base network | 13 |
| A-import-now | 12 |
| Amplify apps/branches/domains | 11 |
| security groups (need names) | 10 |
| service-created log groups | 8 |
| KMS keys (service vs customer) | 6 |
| EC2 compute the stack also creates | 6 |
| AMIs and launch templates | 3 |
| key pairs (import by name) | 2 |
| other decisions | 2 |
| already in Terraform (bootstrap/) | 2 |
| backup artifact | 2 |
| the inventory tool itself | 2 |
| code connections | 1 |
| hand-built pipelines | 1 |
| AWS-managed by another service | 1 |
| no Terraform resource for it | 1 |

## By service

| Service | Total | A | B | C | D | X |
|---|---:|---:|---:|---:|---:|---:|
| ec2 | 70 | 0 | 12 | 13 | 9 | 36 |
| logs | 27 | 10 | 0 | 0 | 8 | 9 |
| amplify | 11 | 0 | 11 | 0 | 0 | 0 |
| lambda | 8 | 0 | 0 | 0 | 1 | 7 |
| memorydb | 8 | 0 | 0 | 0 | 0 | 8 |
| kms | 6 | 0 | 6 | 0 | 0 | 0 |
| rds | 6 | 0 | 0 | 0 | 0 | 6 |
| cloudformation | 5 | 0 | 0 | 0 | 0 | 5 |
| s3 | 5 | 1 | 0 | 0 | 1 | 3 |
| apprunner | 2 | 0 | 0 | 0 | 0 | 2 |
| athena | 2 | 0 | 0 | 0 | 0 | 2 |
| ecr | 2 | 1 | 0 | 0 | 0 | 1 |
| events | 2 | 0 | 0 | 0 | 0 | 2 |
| resource-explorer-2 | 2 | 0 | 0 | 0 | 0 | 2 |
| secretsmanager | 2 | 0 | 0 | 0 | 0 | 2 |
| ssm | 2 | 0 | 0 | 0 | 0 | 2 |
| codeconnections | 1 | 0 | 1 | 0 | 0 | 0 |
| codepipeline | 1 | 0 | 0 | 0 | 1 | 0 |
| ecs | 1 | 0 | 0 | 0 | 0 | 1 |
| elasticache | 1 | 0 | 0 | 0 | 0 | 1 |
| xray | 1 | 0 | 0 | 0 | 0 | 1 |

## Everything, classified

| Bucket | Service | Resource | Terraform type | Import ID | Why |
|---|---|---|---|---|---|
| A-import-now | ecr | `nomaos` | aws_ecr_repository | `nomaos` | ECR repository - import so the lifecycle policy and scan-on-push are in code |
| A-import-now | logs | `/agx/staging/api` | aws_cloudwatch_log_group | `/agx/staging/api` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `/nomaos/prod/api` | aws_cloudwatch_log_group | `/nomaos/prod/api` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `/nomaos/staging/api` | aws_cloudwatch_log_group | `/nomaos/staging/api` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `ec2-auth` | aws_cloudwatch_log_group | `ec2-auth` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `ec2-cloud-init` | aws_cloudwatch_log_group | `ec2-cloud-init` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `ec2-cloud-init-output` | aws_cloudwatch_log_group | `ec2-cloud-init-output` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `ec2-kernel` | aws_cloudwatch_log_group | `ec2-kernel` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `ec2-syslog` | aws_cloudwatch_log_group | `ec2-syslog` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `nginx-access` | aws_cloudwatch_log_group | `nginx-access` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `nginx-error` | aws_cloudwatch_log_group | `nginx-error` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | s3 | `agrovesto-storage-dev` | aws_s3_bucket | `agrovesto-storage-dev` | S3 bucket holding real data - import so versioning, encryption and the public-access block live in code instead of the console |
| B-amplify | amplify | `d1grwi75us24mx` | aws_amplify_app | `d1grwi75us24mx` | Amplify app d1grwi75us24mx - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but no app names, so o... |
| B-amplify | amplify | `d1grwi75us24mx/branches/staging` | aws_amplify_branch | `d1grwi75us24mx/staging` | Amplify branch 'staging' of app d1grwi75us24mx - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids bu... |
| B-amplify | amplify | `d1grwi75us24mx/domains/dev-insight.nomaos.com` | aws_amplify_domain_association | `d1grwi75us24mx/dev-insight.nomaos.com` | Amplify custom domain dev-insight.nomaos.com on app d1grwi75us24mx - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the r... |
| B-amplify | amplify | `d3v79u00ot9glq` | aws_amplify_app | `d3v79u00ot9glq` | Amplify app d3v79u00ot9glq - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but no app names, so o... |
| B-amplify | amplify | `d3v79u00ot9glq/branches/dev` | aws_amplify_branch | `d3v79u00ot9glq/dev` | Amplify branch 'dev' of app d3v79u00ot9glq - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but no... |
| B-amplify | amplify | `d3v79u00ot9glq/domains/dev-onboarding.nomaos.com` | aws_amplify_domain_association | `d3v79u00ot9glq/dev-onboarding.nomaos.com` | Amplify custom domain dev-onboarding.nomaos.com on app d3v79u00ot9glq - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and th... |
| B-amplify | amplify | `d83we1jws50dz` | aws_amplify_app | `d83we1jws50dz` | Amplify app d83we1jws50dz - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but no app names, so ow... |
| B-amplify | amplify | `d83we1jws50dz/branches/staging` | aws_amplify_branch | `d83we1jws50dz/staging` | Amplify branch 'staging' of app d83we1jws50dz - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but... |
| B-amplify | amplify | `dfvk5chhp2iln` | aws_amplify_app | `dfvk5chhp2iln` | Amplify app dfvk5chhp2iln - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but no app names, so ow... |
| B-amplify | amplify | `dfvk5chhp2iln/branches/staging` | aws_amplify_branch | `dfvk5chhp2iln/staging` | Amplify branch 'staging' of app dfvk5chhp2iln - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but... |
| B-amplify | amplify | `dfvk5chhp2iln/domains/dev.nomaos.com` | aws_amplify_domain_association | `dfvk5chhp2iln/dev.nomaos.com` | Amplify custom domain dev.nomaos.com on app dfvk5chhp2iln - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has... |
| B-code-connection | codeconnections | `34fe4280-df27-43a0-b239-95a71c4c1d9b` | aws_codeconnections_connection | `arn:aws:codeconnections:eu-west-1:353833416626:connection/34fe4280-df27-43a0-b239-95a71c4c1d9b` | GitHub connection - the CDK pipeline stack creates one too, so check which tool made this |
| B-key-pair | ec2 | `key-0748e9b8e2b76c283` | aws_key_pair | - | aws_key_pair imports by key pair NAME; the report only has the key-pair id |
| B-key-pair | ec2 | `key-0abcffe745fbd2ac6` | aws_key_pair | - | aws_key_pair imports by key pair NAME; the report only has the key-pair id |
| B-kms-key | kms | `175a4654-4efd-4714-a330-11354749d045` | aws_kms_key | `175a4654-4efd-4714-a330-11354749d045` | AWS service keys and customer-managed keys look identical in an ARN, and a service key (alias/aws/...) cannot be imported at all |
| B-kms-key | kms | `2da3f5ae-f298-4779-b578-daa7a5978e01` | aws_kms_key | `2da3f5ae-f298-4779-b578-daa7a5978e01` | AWS service keys and customer-managed keys look identical in an ARN, and a service key (alias/aws/...) cannot be imported at all |
| B-kms-key | kms | `31f57b1f-cbde-4aa6-8c6e-18e129c80fb6` | aws_kms_key | `31f57b1f-cbde-4aa6-8c6e-18e129c80fb6` | AWS service keys and customer-managed keys look identical in an ARN, and a service key (alias/aws/...) cannot be imported at all |
| B-kms-key | kms | `43990620-5942-4f67-92eb-f99ba9c952ef` | aws_kms_key | `43990620-5942-4f67-92eb-f99ba9c952ef` | AWS service keys and customer-managed keys look identical in an ARN, and a service key (alias/aws/...) cannot be imported at all |
| B-kms-key | kms | `738231a4-4e8e-492c-81c6-30ac229cf08d` | aws_kms_key | `738231a4-4e8e-492c-81c6-30ac229cf08d` | AWS service keys and customer-managed keys look identical in an ARN, and a service key (alias/aws/...) cannot be imported at all |
| B-kms-key | kms | `f44ceb3c-5117-4052-88a2-d2d265699c01` | aws_kms_key | `f44ceb3c-5117-4052-88a2-d2d265699c01` | AWS service keys and customer-managed keys look identical in an ARN, and a service key (alias/aws/...) cannot be imported at all |
| B-security-group | ec2 | `sg-002ee2d53f67176cb` | aws_security_group | `sg-002ee2d53f67176cb` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-003093b317e5032f7` | aws_security_group | `sg-003093b317e5032f7` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-032197de8d143373f` | aws_security_group | `sg-032197de8d143373f` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-039c167fa924e64ee` | aws_security_group | `sg-039c167fa924e64ee` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-05943db64467559f0` | aws_security_group | `sg-05943db64467559f0` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-061cfa042aa584410` | aws_security_group | `sg-061cfa042aa584410` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-0c03238e678039ac4` | aws_security_group | `sg-0c03238e678039ac4` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-0c4d118c6776629d9` | aws_security_group | `sg-0c4d118c6776629d9` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-0d8184650fd775043` | aws_security_group | `sg-0d8184650fd775043` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-0e299611b6b1a93fd` | aws_security_group | `sg-0e299611b6b1a93fd` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| C-network | ec2 | `acl-0ac9d68464b5edd0a` | aws_network_acl | `acl-0ac9d68464b5edd0a` | base network. Live network-acl, which dev/ does not define at all - importing it adds a new managed resource, but a change here affects the whole VPC - and if cidr_blo... |
| C-network | ec2 | `dopt-027b4583e1bb5bda0` | aws_vpc_dhcp_options | `dopt-027b4583e1bb5bda0` | base network. Live dhcp-options, which dev/ does not define at all - importing it adds a new managed resource, but a change here affects the whole VPC - and if cidr_bl... |
| C-network | ec2 | `igw-04e4d65d903b2b67d` | aws_internet_gateway | `igw-04e4d65d903b2b67d` | base network. Imported into aws_internet_gateway.main, the address dev/ already defines, Terraform adopts the LIVE internet-gateway - and if cidr_block or the route en... |
| C-network | ec2 | `rtb-018e7f1b9df073189` | aws_route_table | `rtb-018e7f1b9df073189` | base network. Live route-table. dev/ creates its own route tables from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or acce... |
| C-network | ec2 | `rtb-04a4e32b4443f50d5` | aws_route_table | `rtb-04a4e32b4443f50d5` | base network. Live route-table. dev/ creates its own route tables from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or acce... |
| C-network | ec2 | `rtb-05817e82c2f16f0a4` | aws_route_table | `rtb-05817e82c2f16f0a4` | base network. Live route-table. dev/ creates its own route tables from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or acce... |
| C-network | ec2 | `rtb-0faede26619f355d8` | aws_route_table | `rtb-0faede26619f355d8` | base network. Live route-table. dev/ creates its own route tables from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or acce... |
| C-network | ec2 | `rtb-0fea2a4ff5a3adf0f` | aws_route_table | `rtb-0fea2a4ff5a3adf0f` | base network. Live route-table. dev/ creates its own route tables from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or acce... |
| C-network | ec2 | `subnet-004a7f9d9cbd53ea4` | aws_subnet | `subnet-004a7f9d9cbd53ea4` | base network. Live subnet. dev/ creates its own subnets from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or accepting a se... |
| C-network | ec2 | `subnet-0304d72cd90dd43d9` | aws_subnet | `subnet-0304d72cd90dd43d9` | base network. Live subnet. dev/ creates its own subnets from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or accepting a se... |
| C-network | ec2 | `subnet-0309fc43ea380ad6b` | aws_subnet | `subnet-0309fc43ea380ad6b` | base network. Live subnet. dev/ creates its own subnets from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or accepting a se... |
| C-network | ec2 | `subnet-0739cfd4c412deb3f` | aws_subnet | `subnet-0739cfd4c412deb3f` | base network. Live subnet. dev/ creates its own subnets from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or accepting a se... |
| C-network | ec2 | `vpc-0d9b566c353787d53` | aws_vpc | `vpc-0d9b566c353787d53` | base network. Imported into aws_vpc.main, the address dev/ already defines, Terraform adopts the LIVE vpc - and if cidr_block or the route entries differ from the conf... |
| D-compute | ec2 | `eipalloc-0b7f04c0906f47a4e` | aws_eip | `eipalloc-0b7f04c0906f47a4e` | Elastic IP. The stacks create their own (dev: aws_eip.app for the host, prod: aws_eip.nat for the NAT gateway) - adopting this one has to go into the right address or ... |
| D-compute | ec2 | `i-00af32231113d64f9` | aws_instance | `i-00af32231113d64f9` | EC2 instance. dev/ec2.tf creates its own app host (t3.large, Ubuntu AMI, cloud-init user_data); adopting this box instead means matching ami, instance_type, user_data ... |
| D-compute | ec2 | `i-050358d69e4220585` | aws_instance | `i-050358d69e4220585` | EC2 instance. dev/ec2.tf creates its own app host (t3.large, Ubuntu AMI, cloud-init user_data); adopting this box instead means matching ami, instance_type, user_data ... |
| D-compute | ec2 | `vol-00f63527a001045fa` | aws_ebs_volume | `vol-00f63527a001045fa` | EBS volume attached to an existing host. The stacks create their own (-mssql-data, -logging-data), so adopting this one means matching size, type, AZ and attachment |
| D-compute | ec2 | `vol-082127f70f11b82b9` | aws_ebs_volume | `vol-082127f70f11b82b9` | EBS volume attached to an existing host. The stacks create their own (-mssql-data, -logging-data), so adopting this one means matching size, type, AZ and attachment |
| D-compute | ec2 | `vol-0a13b7e39dd6fb97d` | aws_ebs_volume | `vol-0a13b7e39dd6fb97d` | EBS volume attached to an existing host. The stacks create their own (-mssql-data, -logging-data), so adopting this one means matching size, type, AZ and attachment |
| D-decision | lambda | `test` | aws_lambda_function | `test` | Lambda function 'test' - named like a scratch test; deleting it may be a better answer than adopting it |
| D-decision | s3 | `codepipeline-eu-west-1-3bf3ec101df5-4d09-9689-376482a069ed` | aws_s3_bucket | `codepipeline-eu-west-1-3bf3ec101df5-4d09-9689-376482a069ed` | created by CodePipeline for its own artifacts. Import only if the thing that uses it moves into Terraform too - otherwise Terraform owns a bucket it did not design and... |
| D-log-group | logs | `/aws/amplify/d83we1jws50dz` | aws_cloudwatch_log_group | `/aws/amplify/d83we1jws50dz` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `/aws/apprunner/test/fb582698e8b8432e897d90caf920f6ec/service` | aws_cloudwatch_log_group | `/aws/apprunner/test/fb582698e8b8432e897d90caf920f6ec/service` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `/aws/codepipeline/nomaos` | aws_cloudwatch_log_group | `/aws/codepipeline/nomaos` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `/aws/rds/instance/agxdbinstance/error` | aws_cloudwatch_log_group | `/aws/rds/instance/agxdbinstance/error` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `/aws/rds/instance/nomaos/agent` | aws_cloudwatch_log_group | `/aws/rds/instance/nomaos/agent` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `/aws/rds/instance/nomaos/error` | aws_cloudwatch_log_group | `/aws/rds/instance/nomaos/error` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `/aws/rds/instance/nomaosdbinstance/error` | aws_cloudwatch_log_group | `/aws/rds/instance/nomaosdbinstance/error` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `RDSOSMetrics` | aws_cloudwatch_log_group | `RDSOSMetrics` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-machine-image | ec2 | `ami-0f00a1ff1492a226d` | aws_ami | `ami-0f00a1ff1492a226d` | private AMI - a build artifact. Terraform can own it, but `terraform destroy` then deregisters the image / deletes the template |
| D-machine-image | ec2 | `ami-0fd912de0c8674a38` | aws_ami | `ami-0fd912de0c8674a38` | private AMI - a build artifact. Terraform can own it, but `terraform destroy` then deregisters the image / deletes the template |
| D-machine-image | ec2 | `lt-014a3e4ca5da5d14f` | aws_launch_template | `lt-014a3e4ca5da5d14f` | launch template - a build artifact. Terraform can own it, but `terraform destroy` then deregisters the image / deletes the template |
| D-pipeline | codepipeline | `nomaos` | aws_codepipeline | `nomaos` | hand-built pipeline. Importing it means importing its artifact bucket and IAM role too, or the next plan wants to replace them |
| X-already-managed | s3 | `nomaos-tfstate-353833416626-eu-west-1` | - | - | created by bootstrap/ - the Terraform state bucket stack already owns it |
| X-already-managed | s3 | `nomaos-tfstate-logs-353833416626-eu-west-1` | - | - | created by bootstrap/ - the Terraform state bucket stack already owns it |
| X-aws-default | apprunner | `DefaultConfiguration/1/00000000000000000000000000000001` | - | - | AWS-provided default autoscalingconfiguration 'DefaultConfiguration/1/00000000000000000000000000000001' |
| X-aws-default | athena | `AwsDataCatalog` | - | - | AWS-owned default datacatalog 'AwsDataCatalog' - shared and immutable |
| X-aws-default | athena | `primary` | - | - | AWS-owned default workgroup 'primary' - shared and immutable |
| X-aws-default | elasticache | `default` | - | - | AWS-owned default user 'default' - shared and immutable |
| X-aws-default | events | `default` | - | - | AWS-owned default event-bus 'default' - shared and immutable |
| X-aws-default | memorydb | `default` | - | - | AWS-owned default user 'default' - shared and immutable |
| X-aws-default | memorydb | `default.memorydb-redis6` | - | - | AWS-provided default parametergroup 'default.memorydb-redis6' |
| X-aws-default | memorydb | `default.memorydb-redis7` | - | - | AWS-provided default parametergroup 'default.memorydb-redis7' |
| X-aws-default | memorydb | `default.memorydb-redis7.search` | - | - | AWS-provided default parametergroup 'default.memorydb-redis7.search' |
| X-aws-default | memorydb | `default.memorydb-redis7.search.preview` | - | - | AWS-provided default parametergroup 'default.memorydb-redis7.search.preview' |
| X-aws-default | memorydb | `default.memorydb-valkey7` | - | - | AWS-provided default parametergroup 'default.memorydb-valkey7' |
| X-aws-default | memorydb | `default.memorydb-valkey7.search` | - | - | AWS-provided default parametergroup 'default.memorydb-valkey7.search' |
| X-aws-default | memorydb | `open-access` | - | - | AWS-owned default acl 'open-access' - shared and immutable |
| X-aws-default | rds | `default.sqlserver-ex-15.0` | - | - | AWS-provided default pg 'default.sqlserver-ex-15.0' |
| X-aws-default | rds | `default.sqlserver-se-15.0` | - | - | AWS-provided default pg 'default.sqlserver-se-15.0' |
| X-aws-default | rds | `default:sqlserver-ex-15-00` | - | - | AWS-provided default og 'default:sqlserver-ex-15-00' |
| X-aws-default | rds | `default:sqlserver-se-15-00` | - | - | AWS-provided default og 'default:sqlserver-se-15-00' |
| X-aws-default | xray | `Default` | - | - | AWS-owned default sampling-rule 'Default' - shared and immutable |
| X-aws-managed | events | `AWSUserNotificationsManagedRule-afo4sbg` | - | - | AWS-managed EventBridge rule |
| X-backup | ec2 | `snap-008f1c1a56ca251b7` | - | - | EBS snapshot - a backup artifact, not infrastructure |
| X-backup | ec2 | `snap-02bcd30dd064d2166` | - | - | EBS snapshot - a backup artifact, not infrastructure |
| X-cdk | cloudformation | `CDKToolkit/c37cb950-bfcc-11f0-8df0-06269ce8eae9` | - | - | CloudFormation stack 'CDKToolkit/c37cb950-bfcc-11f0-8df0-06269ce8eae9' - owned by whatever deployed it (CDK here) |
| X-cdk | cloudformation | `Infra-ECS-Cluster-agrovesto-dev-aeff3897/317c5d20-0b27-11f1-ad4b-0696bddfeaf1` | - | - | CloudFormation stack 'Infra-ECS-Cluster-agrovesto-dev-aeff3897/317c5d20-0b27-11f1-ad4b-0696bddfeaf1' - owned by whatever deployed it (CDK here) |
| X-cdk | cloudformation | `agrovesto-infra-deployment-agxdbRotationSingleUser48A10562-1PVI13L3AN0RP/06c918e0-ebd1-11f0-8909-02d062fddbf9` | - | - | CloudFormation stack 'agrovesto-infra-deployment-agxdbRotationSingleUser48A10562-1PVI13L3AN0RP/06c918e0-ebd1-11f0-8909-02d062fddbf9' - owned by whatever deployed it (C... |
| X-cdk | cloudformation | `agrovesto-infra-deployment-nomaosdbRotationSingleUserE9E23701-MOZWSTLAC715/d71e6450-ea28-11f0-a02f-0ad4becf83eb` | - | - | CloudFormation stack 'agrovesto-infra-deployment-nomaosdbRotationSingleUserE9E23701-MOZWSTLAC715/d71e6450-ea28-11f0-a02f-0ad4becf83eb' - owned by whatever deployed it ... |
| X-cdk | cloudformation | `agrovesto-infra-deployment/bfc6beb0-ea28-11f0-83fa-02252229d469` | - | - | CloudFormation stack 'agrovesto-infra-deployment/bfc6beb0-ea28-11f0-83fa-02252229d469' - owned by whatever deployed it (CDK here) |
| X-cdk | ecr | `cdk-hnb659fds-container-assets-353833416626-eu-west-1` | - | - | CDK bootstrap container-asset repository |
| X-cdk | ecs | `agrovesto-dev` | - | - | ECS cluster created by the CloudFormation stack Infra-ECS-Cluster-agrovesto-dev |
| X-cdk | lambda | `agrovesto-infra-deploymen-CustomVpcRestrictDefault-nZX8uP3WCqzp` | - | - | CDK construct lambda (agrovesto-infra-deploymen-CustomVpcRestrictDefault-nZX8uP3WCqzp) - rewritten on every cdk deploy |
| X-cdk | lambda | `agrovestoinfradeploymentagxdbRotationSingleUser096353C8` | - | - | CDK construct lambda (agrovestoinfradeploymentagxdbRotationSingleUser096353C8) - rewritten on every cdk deploy |
| X-cdk | lambda | `agrovestoinfradeploymentnomaosdbRotationSingleUser77906076` | - | - | CDK construct lambda (agrovestoinfradeploymentnomaosdbRotationSingleUser77906076) - rewritten on every cdk deploy |
| X-cdk | logs | `/aws/lambda/agrovesto-infra-deploymen-CustomVpcRestrictDefault-KU3EPogQo5Br` | - | - | log group of a CDK custom-resource lambda |
| X-cdk | logs | `/aws/lambda/agrovesto-infra-deploymen-CustomVpcRestrictDefault-nZX8uP3WCqzp` | - | - | log group of a CDK custom-resource lambda |
| X-cdk | logs | `/aws/lambda/agrovestoinfradeploymentagxdbRotationSingleUser096353C8` | - | - | log group of a CDK custom-resource lambda |
| X-cdk | logs | `/aws/lambda/agrovestoinfradeploymentnomaosdbRotationSingleUser77906076` | - | - | log group of a CDK custom-resource lambda |
| X-cdk | logs | `/aws/lambda/amplify-reactvitetailwind-CustomCDKBucketDeploymen-VfnRjrAwAUEB` | - | - | log group of a CDK custom-resource lambda |
| X-cdk | logs | `/aws/lambda/amplify-reactvitetailwind-CustomS3AutoDeleteObject-E8AAR8n4318u` | - | - | log group of a CDK custom-resource lambda |
| X-cdk | logs | `/aws/lambda/amplify-reactvitetailwind-CustomS3AutoDeleteObject-aSThv5jkev7C` | - | - | log group of a CDK custom-resource lambda |
| X-cdk | logs | `/aws/lambda/amplify-reactvitetailwind-TableManagerCustomProvid-KHb5ED3lfMmU` | - | - | log group of a CDK custom-resource lambda |
| X-cdk | logs | `/aws/lambda/amplify-reactvitetailwind-TableManagerCustomProvid-ueZTCRxhdAWz` | - | - | log group of a CDK custom-resource lambda |
| X-cdk | rds | `agxdbsubnetgroup` | - | - | subnet group of a CDK-managed RDS instance |
| X-cdk | rds | `nomaosdbsubnetgroup` | - | - | subnet group of a CDK-managed RDS instance |
| X-cdk | s3 | `cdk-hnb659fds-assets-353833416626-eu-west-1` | - | - | CDK bootstrap asset bucket |
| X-cdk | secretsmanager | `agxDBcredentials-5lcSd1` | - | - | CDK DatabaseSecret belonging to the CDK-managed RDS instance |
| X-cdk | secretsmanager | `nomaosDBcredentials-u4Bs7W` | - | - | CDK DatabaseSecret belonging to the CDK-managed RDS instance |
| X-cdk | ssm | `cdk-bootstrap/hnb659fds/version` | - | - | CDK bootstrap version marker |
| X-derived | ec2 | `eni-0231d1a37e9e5520c` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-0247753726aa16b94` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-05514ddcf30ab71e1` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-05e09ba4adc635a02` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-08578e4affa50883e` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-08f040a1b5fffbbd8` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-0bcfbc9a627cf4e67` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-0ce0d9bf0c6aafdf8` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-0eff27e9b957f81d3` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-0ffbb43a3dd312fca` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `sgr-00af9200ae203124b` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-00c2e08694447c8b9` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0244e46320fa0f09e` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-03243c259ffb57ae5` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-032dd668089583899` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-03421580eaec7ee6d` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-039655ccb8c02c6c8` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-045239d6a3a7ed3ec` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-04c887d7641bf115f` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-059cf321e92350e92` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-06509adefc589c1b0` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0733224a8fac9b105` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-07372b78ce908a026` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-081eb722e4867b20a` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-083ad12b696c9517b` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-09162b6d36c69f9a3` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-098181c090e9b0195` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0a3b38afa7bc540c0` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0b1841c44fcf84c1e` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0b5ec5b38860cee82` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0cc257d5f4eab3d90` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0e092148f72a1d265` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0e3746e936c89f11f` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0f3ed2f212465c174` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | lambda | `agrovesto-infra-deploymen-CustomVpcRestrictDefault-nZX8uP3WCqzp:$LATEST` | - | - | the $LATEST pseudo-version of a function; the function itself is the resource |
| X-derived | lambda | `agrovestoinfradeploymentagxdbRotationSingleUser096353C8:$LATEST` | - | - | the $LATEST pseudo-version of a function; the function itself is the resource |
| X-derived | lambda | `agrovestoinfradeploymentnomaosdbRotationSingleUser77906076:$LATEST` | - | - | the $LATEST pseudo-version of a function; the function itself is the resource |
| X-derived | lambda | `test:$LATEST` | - | - | the $LATEST pseudo-version of a function; the function itself is the resource |
| X-derived | ssm | `i-00af32231113d64f9` | - | - | the SSM registration of EC2 instance i-00af32231113d64f9 - import the instance, not this |
| X-no-tf-resource | apprunner | `test-project/6f7fbcd464b94d16b9177ae1c034c708` | - | - | App Runner source connection - the provider has no resource for it |
| X-tooling | resource-explorer-2 | `5a315ef4-dfcb-47cf-bea0-815907217a6c` | - | - | Resource Explorer's own index - the tool that produced this inventory |
| X-tooling | resource-explorer-2 | `eu-west-1/b9917b43-4a1a-4504-ac28-274a4e9c3b1e` | - | - | Resource Explorer's own view - the tool that produced this inventory |
