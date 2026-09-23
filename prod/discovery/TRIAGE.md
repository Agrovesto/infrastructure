# prod/ - what the AWS inventory means for this folder

Generated 2026-09-23 by `scripts/import-from-inventory.py` from the AWS Resource Explorer 2 inventory of 2026-09-23 (375 resources, eu-west-1, accounts 353833416626 + 221434544570).
Account(s): 221434544570. Region indexed: eu-west-1 only.

**210 resources indexed: 20 ready to import, 47 needing one check, 13 network, 25 decisions, 105 excluded.**

Import blocks: [`discovery/imports/imports-prod.tf.txt`](imports/imports-prod.tf.txt). Every row with its reason: `discovery/inventory-2026-09-23.csv`.

## Read this first

**105 of 210 indexed resources are excluded.** They are AWS-owned defaults (`default.memorydb-*`, `primary` Athena workgroup, the `Default` X-Ray rule), resources another tool owns (CDK/CloudFormation stacks are deployed in this account), children of a parent resource (ENIs, individual security-group rules, `$LATEST` function versions), backup artifacts (EBS/RDS snapshots), or the Resource Explorer index itself. Importing any of those either fails outright or starts a fight between two tools.

**This inventory has no names and no tags.** Resource Explorer returns ARNs, so nothing here can prove whether a security group, KMS key, Amplify app or bucket is yours, a service's, or CDK's. That is why every bucket-B row carries the single command that answers it, and why no bucket-B block is uncommented.

**Coverage is eu-west-1 only, and global services are missing.** Route 53 hosted zones and IAM identities are indexed in us-east-1, so their absence here means nothing. `scripts/aws-inventory-scan.sh` uses describe calls and sees them - run it before trusting any 'this does not exist' conclusion on this page.

**No load balancer, no ECS cluster or service, no EFS and no NAT gateway are indexed in this account**, yet `prod/` defines all of them (ALB, Fargate services, EFS for Vault, NAT gateway). Either the prod stack has never been applied or those resources are gone. Confirm with `aws elbv2 describe-load-balancers`, `aws ecs list-clusters` and `aws efs describe-file-systems` before importing anything into an address `prod/` already defines.

**SES identities in this account: `agrovesto.com`, `info@agrovesto.com`, `tech@agrovesto.com`.** `monitoring/` (which deploys into this same account) verifies `var.report_ses_domain`, defaulting to `nomaos.com` - a domain that is *not* verified here. So either import the existing `agrovesto.com` identity into `monitoring/` and set `report_ses_domain = "agrovesto.com"`, or let monitoring verify `nomaos.com`. Do not do both.

## Does this stack exist in the account yet?

`prod/` creates resources named `agrovesto-prod-*`. Of the 14 names it would use, **none exist in this account**: `agrovesto-prod-alb`, `agrovesto-prod-alb-logs`, `agrovesto-prod-alb-sg`, `agrovesto-prod-ecs-sg`, `agrovesto-prod-efs-sg`, `agrovesto-prod-mssql`, `agrovesto-prod-mssql-master`, `agrovesto-prod-nat-1`, `agrovesto-prod-private-1`, `agrovesto-prod-public-1` (and 4 more).

That is the most important fact on this page: **the `prod/` stack has not been applied to this account.** Most of what it defines must therefore be *created*, not imported. The resources worth importing are the ones it would otherwise duplicate - the VPC, subnets, route tables, buckets and databases that already exist - because creating a second copy of those is what costs money and causes outages.

Before any of this: `terraform -chdir=prod state list`. If it is empty, the stack has no state and every import below is a first adoption; if it is not empty, reconcile the list against section A first, because importing a resource that is already in state under a different address fails with 'resource already managed'.

## Buckets

| Bucket | Count | Meaning |
|---|---:|---|
| **A - import now** | 20 | Standalone resources nothing in the repo claims - paste and plan. |
| **B - one command decides the address** | 47 | Correct address depends on a name/domain/owner the ARN does not carry; each block has the one command that reveals it. |
| **C - base network: read the warning before touching this** | 13 | Live VPC, subnets, route tables, gateway, NACL, DHCP options. Adopting them can force a replacement if the config's CIDRs differ - verify first. |
| **D - a decision, not a discovery** | 25 | Exists, but whether Terraform should own it is a policy call (scratch resources, build artifacts, service-created log groups, compute the stack creates fresh). |
| **X - excluded** | 105 | Not importable, or importing it would be wrong: see the breakdown below. |

| Group | Count |
|---|---:|
| derived from a parent resource | 55 |
| owned by CDK / CloudFormation | 24 |
| A-import-now | 20 |
| Amplify apps/branches/domains | 19 |
| AWS-owned default | 16 |
| security groups (need names) | 13 |
| base network | 13 |
| service-created log groups | 13 |
| KMS keys (service vs customer) | 6 |
| backup artifact | 5 |
| other decisions | 4 |
| key pairs (import by name) | 3 |
| EC2 compute the stack also creates | 3 |
| hand-built pipelines | 3 |
| ACM certificates (which domain?) | 2 |
| code connections | 2 |
| AMIs and launch templates | 2 |
| the inventory tool itself | 2 |
| RDS instances | 1 |
| SSM parameters (leading slash?) | 1 |
| already in Terraform (bootstrap/) | 1 |
| AWS-managed by another service | 1 |
| ephemeral | 1 |

## By service

| Service | Total | A | B | C | D | X |
|---|---:|---:|---:|---:|---:|---:|
| ec2 | 82 | 0 | 16 | 13 | 5 | 48 |
| logs | 27 | 9 | 0 | 0 | 13 | 5 |
| amplify | 19 | 0 | 19 | 0 | 0 | 0 |
| rds | 11 | 0 | 1 | 0 | 0 | 10 |
| memorydb | 8 | 0 | 0 | 0 | 0 | 8 |
| s3 | 7 | 1 | 0 | 0 | 4 | 2 |
| kms | 6 | 0 | 6 | 0 | 0 | 0 |
| lambda | 6 | 0 | 0 | 0 | 0 | 6 |
| cloudformation | 5 | 0 | 0 | 0 | 0 | 5 |
| codepipeline | 5 | 0 | 0 | 0 | 3 | 2 |
| dms | 5 | 4 | 0 | 0 | 0 | 1 |
| ssm | 5 | 1 | 1 | 0 | 0 | 3 |
| ses | 4 | 4 | 0 | 0 | 0 | 0 |
| secretsmanager | 3 | 0 | 0 | 0 | 0 | 3 |
| acm | 2 | 0 | 2 | 0 | 0 | 0 |
| athena | 2 | 0 | 0 | 0 | 0 | 2 |
| events | 2 | 0 | 0 | 0 | 0 | 2 |
| resource-explorer-2 | 2 | 0 | 0 | 0 | 0 | 2 |
| sns | 2 | 1 | 0 | 0 | 0 | 1 |
| apprunner | 1 | 0 | 0 | 0 | 0 | 1 |
| codebuild | 1 | 0 | 0 | 0 | 0 | 1 |
| codeconnections | 1 | 0 | 1 | 0 | 0 | 0 |
| codestar-connections | 1 | 0 | 1 | 0 | 0 | 0 |
| ecr | 1 | 0 | 0 | 0 | 0 | 1 |
| elasticache | 1 | 0 | 0 | 0 | 0 | 1 |
| xray | 1 | 0 | 0 | 0 | 0 | 1 |

## Everything, classified

| Bucket | Service | Resource | Terraform type | Import ID | Why |
|---|---|---|---|---|---|
| A-import-now | dms | `BSI5NFYJSVELZMYVPFOMJ56MIM` | aws_dms_endpoint | `BSI5NFYJSVELZMYVPFOMJ56MIM` | DMS endpoint - import so the migration source/target is in code. Note the DMS serverless replications themselves are not in this index, so this is part of a larger pic... |
| A-import-now | dms | `WFZ6YQ2JCJBLLBLRDLCH7XNRWY` | aws_dms_endpoint | `WFZ6YQ2JCJBLLBLRDLCH7XNRWY` | DMS endpoint - import so the migration source/target is in code. Note the DMS serverless replications themselves are not in this index, so this is part of a larger pic... |
| A-import-now | dms | `agxdb` | aws_dms_endpoint | `agxdb` | DMS endpoint - import so the migration source/target is in code. Note the DMS serverless replications themselves are not in this index, so this is part of a larger pic... |
| A-import-now | dms | `nomaos` | aws_dms_endpoint | `nomaos` | DMS endpoint - import so the migration source/target is in code. Note the DMS serverless replications themselves are not in this index, so this is part of a larger pic... |
| A-import-now | logs | `/nomaos/prod/api` | aws_cloudwatch_log_group | `/nomaos/prod/api` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `ec2-auth` | aws_cloudwatch_log_group | `ec2-auth` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `ec2-cloud-init` | aws_cloudwatch_log_group | `ec2-cloud-init` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `ec2-cloud-init-output` | aws_cloudwatch_log_group | `ec2-cloud-init-output` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `ec2-kernel` | aws_cloudwatch_log_group | `ec2-kernel` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `ec2-syslog` | aws_cloudwatch_log_group | `ec2-syslog` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `nginx-access` | aws_cloudwatch_log_group | `nginx-access` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `nginx-error` | aws_cloudwatch_log_group | `nginx-error` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | logs | `noma-api` | aws_cloudwatch_log_group | `noma-api` | hand-made log group (not one a service created) - import to pin retention |
| A-import-now | s3 | `agrovesto-storage` | aws_s3_bucket | `agrovesto-storage` | S3 bucket holding real data - import so versioning, encryption and the public-access block live in code instead of the console |
| A-import-now | ses | `agrovesto.com` | aws_ses_domain_identity | `agrovesto.com` | SES domain identity - import so the verification and DKIM records are in code |
| A-import-now | ses | `info@agrovesto.com` | aws_ses_email_identity | `info@agrovesto.com` | SES email identity - import so its verification state is in code |
| A-import-now | ses | `my-first-configuration-set` | aws_ses_configuration_set | `my-first-configuration-set` | SES configuration set - import so its event destinations are in code |
| A-import-now | ses | `tech@agrovesto.com` | aws_ses_email_identity | `tech@agrovesto.com` | SES email identity - import so its verification state is in code |
| A-import-now | sns | `agrovesto` | aws_sns_topic | `arn:aws:sns:eu-west-1:221434544570:agrovesto` | SNS topic - import so its policy and subscriptions are in code |
| A-import-now | ssm | `ef34e30b-8367-4e4e-96d6-573010af70ef` | aws_ssm_association | `ef34e30b-8367-4e4e-96d6-573010af70ef` | SSM State Manager association - import so its document and schedule are in code |
| B-acm-certificate | acm | `5172b3e7-972d-46c1-87f3-dc104934ac64` | aws_acm_certificate | `arn:aws:acm:eu-west-1:221434544570:certificate/5172b3e7-972d-46c1-87f3-dc104934ac64` | prod/acm.tf already defines aws_acm_certificate.wildcard for *.nomaos.com - if this is that certificate it must go into THAT address, not a new one |
| B-acm-certificate | acm | `f493b7d7-a3bb-4092-a2c9-54bd6655dbd1` | aws_acm_certificate | `arn:aws:acm:eu-west-1:221434544570:certificate/f493b7d7-a3bb-4092-a2c9-54bd6655dbd1` | prod/acm.tf already defines aws_acm_certificate.wildcard for *.nomaos.com - if this is that certificate it must go into THAT address, not a new one |
| B-amplify | amplify | `d24hrz6o3pnmne` | aws_amplify_app | `d24hrz6o3pnmne` | Amplify app d24hrz6o3pnmne - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but no app names, so o... |
| B-amplify | amplify | `d24hrz6o3pnmne/branches/master` | aws_amplify_branch | `d24hrz6o3pnmne/master` | Amplify branch 'master' of app d24hrz6o3pnmne - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but... |
| B-amplify | amplify | `d24hrz6o3pnmne/domains/agrovesto.com` | aws_amplify_domain_association | `d24hrz6o3pnmne/agrovesto.com` | Amplify custom domain agrovesto.com on app d24hrz6o3pnmne - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has... |
| B-amplify | amplify | `d2qsjz4yzplkjb` | aws_amplify_app | `d2qsjz4yzplkjb` | Amplify app d2qsjz4yzplkjb - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but no app names, so o... |
| B-amplify | amplify | `d2qsjz4yzplkjb/branches/master` | aws_amplify_branch | `d2qsjz4yzplkjb/master` | Amplify branch 'master' of app d2qsjz4yzplkjb - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but... |
| B-amplify | amplify | `d2qsjz4yzplkjb/domains/nomaos.com` | aws_amplify_domain_association | `d2qsjz4yzplkjb/nomaos.com` | Amplify custom domain nomaos.com on app d2qsjz4yzplkjb - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has ap... |
| B-amplify | amplify | `d2tux0dpg27k42` | aws_amplify_app | `d2tux0dpg27k42` | Amplify app d2tux0dpg27k42 - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but no app names, so o... |
| B-amplify | amplify | `d2tux0dpg27k42/branches/master` | aws_amplify_branch | `d2tux0dpg27k42/master` | Amplify branch 'master' of app d2tux0dpg27k42 - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but... |
| B-amplify | amplify | `d2uzc83ix5qdfu` | aws_amplify_app | `d2uzc83ix5qdfu` | Amplify app d2uzc83ix5qdfu - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but no app names, so o... |
| B-amplify | amplify | `d2uzc83ix5qdfu/branches/master` | aws_amplify_branch | `d2uzc83ix5qdfu/master` | Amplify branch 'master' of app d2uzc83ix5qdfu - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but... |
| B-amplify | amplify | `d3po2sm2zq4p71` | aws_amplify_app | `d3po2sm2zq4p71` | Amplify app d3po2sm2zq4p71 - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but no app names, so o... |
| B-amplify | amplify | `d3po2sm2zq4p71/branches/main` | aws_amplify_branch | `d3po2sm2zq4p71/main` | Amplify branch 'main' of app d3po2sm2zq4p71 - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but n... |
| B-amplify | amplify | `d3po2sm2zq4p71/domains/trade.agrovesto.com` | aws_amplify_domain_association | `d3po2sm2zq4p71/trade.agrovesto.com` | Amplify custom domain trade.agrovesto.com on app d3po2sm2zq4p71 - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the repo... |
| B-amplify | amplify | `d4d246twq5d12` | aws_amplify_app | `d4d246twq5d12` | Amplify app d4d246twq5d12 - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but no app names, so ow... |
| B-amplify | amplify | `d4d246twq5d12/branches/master` | aws_amplify_branch | `d4d246twq5d12/master` | Amplify branch 'master' of app d4d246twq5d12 - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but ... |
| B-amplify | amplify | `d4d246twq5d12/domains/insight.nomaos.com` | aws_amplify_domain_association | `d4d246twq5d12/insight.nomaos.com` | Amplify custom domain insight.nomaos.com on app d4d246twq5d12 - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report... |
| B-amplify | amplify | `dm0gdjrq9j06v` | aws_amplify_app | `dm0gdjrq9j06v` | Amplify app dm0gdjrq9j06v - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but no app names, so ow... |
| B-amplify | amplify | `dm0gdjrq9j06v/branches/master` | aws_amplify_branch | `dm0gdjrq9j06v/master` | Amplify branch 'master' of app dm0gdjrq9j06v - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the report has app ids but ... |
| B-amplify | amplify | `dm0gdjrq9j06v/domains/onboarding.nomaos.com` | aws_amplify_domain_association | `dm0gdjrq9j06v/onboarding.nomaos.com` | Amplify custom domain onboarding.nomaos.com on app dm0gdjrq9j06v - a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and the rep... |
| B-code-connection | codeconnections | `da07fb91-02f9-4552-9d01-837a9366b681` | aws_codeconnections_connection | `arn:aws:codeconnections:eu-west-1:221434544570:connection/da07fb91-02f9-4552-9d01-837a9366b681` | GitHub connection - the CDK pipeline stack creates one too, so check which tool made this |
| B-code-connection | codestar-connections | `54bd9bd5-955a-4415-873e-aa936036f835` | aws_codestarconnections_connection | `arn:aws:codestar-connections:eu-west-1:221434544570:connection/54bd9bd5-955a-4415-873e-aa936036f835` | GitHub connection - the CDK pipeline stack creates one too, so check which tool made this |
| B-key-pair | ec2 | `key-057e0d6c32eb78e4d` | aws_key_pair | - | aws_key_pair imports by key pair NAME; the report only has the key-pair id |
| B-key-pair | ec2 | `key-075e7652029e2c2c5` | aws_key_pair | - | aws_key_pair imports by key pair NAME; the report only has the key-pair id |
| B-key-pair | ec2 | `key-0b6382b8152c63533` | aws_key_pair | - | aws_key_pair imports by key pair NAME; the report only has the key-pair id |
| B-kms-key | kms | `05d6e0b6-0aef-42ab-9ebc-368642da2498` | aws_kms_key | `05d6e0b6-0aef-42ab-9ebc-368642da2498` | AWS service keys and customer-managed keys look identical in an ARN, and a service key (alias/aws/...) cannot be imported at all |
| B-kms-key | kms | `6e98aa83-4990-4fbe-938a-284763dad588` | aws_kms_key | `6e98aa83-4990-4fbe-938a-284763dad588` | AWS service keys and customer-managed keys look identical in an ARN, and a service key (alias/aws/...) cannot be imported at all |
| B-kms-key | kms | `89a5cab0-dfa9-4d8a-a3d0-c4cbe9672e35` | aws_kms_key | `89a5cab0-dfa9-4d8a-a3d0-c4cbe9672e35` | AWS service keys and customer-managed keys look identical in an ARN, and a service key (alias/aws/...) cannot be imported at all |
| B-kms-key | kms | `af93b781-7db2-418f-ba53-aaf08a0893ba` | aws_kms_key | `af93b781-7db2-418f-ba53-aaf08a0893ba` | AWS service keys and customer-managed keys look identical in an ARN, and a service key (alias/aws/...) cannot be imported at all |
| B-kms-key | kms | `f844da16-3c57-4ba4-9e09-fcd6af19c9f1` | aws_kms_key | `f844da16-3c57-4ba4-9e09-fcd6af19c9f1` | AWS service keys and customer-managed keys look identical in an ARN, and a service key (alias/aws/...) cannot be imported at all |
| B-kms-key | kms | `fc06a828-b6a4-412a-b5f1-417e4ab693e4` | aws_kms_key | `fc06a828-b6a4-412a-b5f1-417e4ab693e4` | AWS service keys and customer-managed keys look identical in an ARN, and a service key (alias/aws/...) cannot be imported at all |
| B-rds-instance | rds | `migration-prod` | aws_db_instance | `migration-prod` | the real database. prod/rds.tf wants identifier 'agrovesto-prod-mssql'; this instance is 'migration-prod', so it imports under a NEW address and the two have to be rec... |
| B-security-group | ec2 | `sg-0121823b5aba80621` | aws_security_group | `sg-0121823b5aba80621` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-044858bb412fc2aa0` | aws_security_group | `sg-044858bb412fc2aa0` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-04778d7bdb8e2c026` | aws_security_group | `sg-04778d7bdb8e2c026` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-05a2722a050c1109b` | aws_security_group | `sg-05a2722a050c1109b` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-06e44543a37f56828` | aws_security_group | `sg-06e44543a37f56828` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-072ebb62525423c86` | aws_security_group | `sg-072ebb62525423c86` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-094939b554d597e4a` | aws_security_group | `sg-094939b554d597e4a` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-09e61cfd83551d0ec` | aws_security_group | `sg-09e61cfd83551d0ec` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-0b555edfc6d445a18` | aws_security_group | `sg-0b555edfc6d445a18` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-0bfbddac52a0a2b89` | aws_security_group | `sg-0bfbddac52a0a2b89` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-0df9c118433af39dd` | aws_security_group | `sg-0df9c118433af39dd` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-0e4ef41f521e66695` | aws_security_group | `sg-0e4ef41f521e66695` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-security-group | ec2 | `sg-0f208f7733ec29fbd` | aws_security_group | `sg-0f208f7733ec29fbd` | security group - the report carries no names, so its owner is unknown. If GroupName turns out to be 'default', the address is aws_default_security_group.default (both ... |
| B-ssm-parameter | ssm | `AmazonCloudWatch-linux` | aws_ssm_parameter | - | an ARN drops the parameter's leading slash, so the import id is either '/AmazonCloudWatch-linux' or 'AmazonCloudWatch-linux' - only get-parameter says which |
| C-network | ec2 | `acl-06b37d7639de1e948` | aws_network_acl | `acl-06b37d7639de1e948` | base network. Live network-acl, which prod/ does not define at all - importing it adds a new managed resource, but a change here affects the whole VPC - and if cidr_bl... |
| C-network | ec2 | `dopt-00fa0eeec7372ed4f` | aws_vpc_dhcp_options | `dopt-00fa0eeec7372ed4f` | base network. Live dhcp-options, which prod/ does not define at all - importing it adds a new managed resource, but a change here affects the whole VPC - and if cidr_b... |
| C-network | ec2 | `igw-07275a1a62726a4c8` | aws_internet_gateway | `igw-07275a1a62726a4c8` | base network. Imported into aws_internet_gateway.main, the address prod/ already defines, Terraform adopts the LIVE internet-gateway - and if cidr_block or the route e... |
| C-network | ec2 | `rtb-0530eb261b38f735b` | aws_route_table | `rtb-0530eb261b38f735b` | base network. Live route-table. prod/ creates its own route tables from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or acc... |
| C-network | ec2 | `rtb-0614ed06de1bc1d89` | aws_route_table | `rtb-0614ed06de1bc1d89` | base network. Live route-table. prod/ creates its own route tables from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or acc... |
| C-network | ec2 | `rtb-084528a52ec739f38` | aws_route_table | `rtb-084528a52ec739f38` | base network. Live route-table. prod/ creates its own route tables from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or acc... |
| C-network | ec2 | `rtb-0fa0841a7b7dac5db` | aws_route_table | `rtb-0fa0841a7b7dac5db` | base network. Live route-table. prod/ creates its own route tables from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or acc... |
| C-network | ec2 | `rtb-0fa42099da11b78e9` | aws_route_table | `rtb-0fa42099da11b78e9` | base network. Live route-table. prod/ creates its own route tables from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or acc... |
| C-network | ec2 | `subnet-00ee6901e53783c86` | aws_subnet | `subnet-00ee6901e53783c86` | base network. Live subnet. prod/ creates its own subnets from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or accepting a s... |
| C-network | ec2 | `subnet-084f21457f316c44c` | aws_subnet | `subnet-084f21457f316c44c` | base network. Live subnet. prod/ creates its own subnets from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or accepting a s... |
| C-network | ec2 | `subnet-0b808deeaf8391867` | aws_subnet | `subnet-0b808deeaf8391867` | base network. Live subnet. prod/ creates its own subnets from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or accepting a s... |
| C-network | ec2 | `subnet-0e169f40c70cdfe8b` | aws_subnet | `subnet-0e169f40c70cdfe8b` | base network. Live subnet. prod/ creates its own subnets from var.*_subnet_cidrs, so importing this one means either matching that variable to reality or accepting a s... |
| C-network | ec2 | `vpc-0016f521bae08f4ff` | aws_vpc | `vpc-0016f521bae08f4ff` | base network. Imported into aws_vpc.main, the address prod/ already defines, Terraform adopts the LIVE vpc - and if cidr_block or the route entries differ from the con... |
| D-compute | ec2 | `eipalloc-0a48ffb921e22bb39` | aws_eip | `eipalloc-0a48ffb921e22bb39` | Elastic IP. The stacks create their own (dev: aws_eip.app for the host, prod: aws_eip.nat for the NAT gateway) - adopting this one has to go into the right address or ... |
| D-compute | ec2 | `i-027ff32f2a26fa600` | aws_instance | `i-027ff32f2a26fa600` | EC2 instance. dev/ec2.tf creates its own app host (t3.large, Ubuntu AMI, cloud-init user_data); adopting this box instead means matching ami, instance_type, user_data ... |
| D-compute | ec2 | `vol-019ff51ce045e3490` | aws_ebs_volume | `vol-019ff51ce045e3490` | EBS volume attached to an existing host. The stacks create their own (-mssql-data, -logging-data), so adopting this one means matching size, type, AZ and attachment |
| D-decision | s3 | `agrovesto-pipeline-artifacts` | aws_s3_bucket | `agrovesto-pipeline-artifacts` | artifact store of a hand-built CodePipeline. Import it together with the pipeline (see the pipeline block below) or not at all: a bucket without its pipeline policy is... |
| D-decision | s3 | `cf-templates-lh5u9ipyvd5c-eu-west-1` | aws_s3_bucket | `cf-templates-lh5u9ipyvd5c-eu-west-1` | created by CloudFormation for its own artifacts. Import only if the thing that uses it moves into Terraform too - otherwise Terraform owns a bucket it did not design a... |
| D-decision | s3 | `codepipeline-eu-west-1-388c27815165-4d9c-97e5-35f4ec8ad1d6` | aws_s3_bucket | `codepipeline-eu-west-1-388c27815165-4d9c-97e5-35f4ec8ad1d6` | created by CodePipeline for its own artifacts. Import only if the thing that uses it moves into Terraform too - otherwise Terraform owns a bucket it did not design and... |
| D-decision | s3 | `dms-serverless-premigration-results-dnwcx6llcg` | aws_s3_bucket | `dms-serverless-premigration-results-dnwcx6llcg` | created by DMS Serverless for its own artifacts. Import only if the thing that uses it moves into Terraform too - otherwise Terraform owns a bucket it did not design a... |
| D-log-group | logs | `/aws/amplify/d3po2sm2zq4p71` | aws_cloudwatch_log_group | `/aws/amplify/d3po2sm2zq4p71` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `/aws/codebuild/agrovesto-ProdCodeBuildProject` | aws_cloudwatch_log_group | `/aws/codebuild/agrovesto-ProdCodeBuildProject` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `/aws/codepipeline/Agx_Trade` | aws_cloudwatch_log_group | `/aws/codepipeline/Agx_Trade` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `/aws/codepipeline/agreovesto-api` | aws_cloudwatch_log_group | `/aws/codepipeline/agreovesto-api` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `/aws/codepipeline/agxtrade` | aws_cloudwatch_log_group | `/aws/codepipeline/agxtrade` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `/aws/codepipeline/argovesto-api-v8` | aws_cloudwatch_log_group | `/aws/codepipeline/argovesto-api-v8` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `/aws/codepipeline/noma-api-new` | aws_cloudwatch_log_group | `/aws/codepipeline/noma-api-new` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `/aws/codepipeline/noma-api-pipeline` | aws_cloudwatch_log_group | `/aws/codepipeline/noma-api-pipeline` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `/aws/codepipeline/noma-new` | aws_cloudwatch_log_group | `/aws/codepipeline/noma-new` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `/aws/rds/instance/migration-prod/error` | aws_cloudwatch_log_group | `/aws/rds/instance/migration-prod/error` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `RDSOSMetrics` | aws_cloudwatch_log_group | `RDSOSMetrics` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `dms-serverless-replication-agx` | aws_cloudwatch_log_group | `dms-serverless-replication-agx` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-log-group | logs | `dms-serverless-replication-nomaos` | aws_cloudwatch_log_group | `dms-serverless-replication-nomaos` | created automatically by the service that writes to it; import only to pin retention_in_days (unbounded retention is the usual surprise on the bill) |
| D-machine-image | ec2 | `lt-017de20e61da8fe44` | aws_launch_template | `lt-017de20e61da8fe44` | launch template - a build artifact. Terraform can own it, but `terraform destroy` then deregisters the image / deletes the template |
| D-machine-image | ec2 | `lt-08897dce459b4913c` | aws_launch_template | `lt-08897dce459b4913c` | launch template - a build artifact. Terraform can own it, but `terraform destroy` then deregisters the image / deletes the template |
| D-pipeline | codepipeline | `Agx_Trade` | aws_codepipeline | `Agx_Trade` | hand-built pipeline. Importing it means importing its artifact bucket and IAM role too, or the next plan wants to replace them |
| D-pipeline | codepipeline | `noma-api-pipeline` | aws_codepipeline | `noma-api-pipeline` | hand-built pipeline. Importing it means importing its artifact bucket and IAM role too, or the next plan wants to replace them |
| D-pipeline | codepipeline | `noma-new` | aws_codepipeline | `noma-new` | hand-built pipeline. Importing it means importing its artifact bucket and IAM role too, or the next plan wants to replace them |
| X-already-managed | s3 | `nomaos-tfstate-221434544570-eu-west-1` | - | - | created by bootstrap/ - the Terraform state bucket stack already owns it |
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
| X-aws-default | rds | `default:sqlserver-ex-15-00` | - | - | AWS-provided default og 'default:sqlserver-ex-15-00' |
| X-aws-default | xray | `Default` | - | - | AWS-owned default sampling-rule 'Default' - shared and immutable |
| X-aws-managed | secretsmanager | `rds!db-9bf3a548-e703-4bfe-a868-2a5b81fa436a-U4iZLd` | - | - | RDS-managed master-password secret - created and rotated by RDS itself |
| X-backup | rds | `ab-zeljsoacnuw2fhj747336kjjzhpy7ij2n5ai6oo2i7vvxvbfjuvlzux7t3dm2vx7` | - | - | RDS auto-backup - a backup artifact, not infrastructure |
| X-backup | rds | `rds:migration-prod-2026-09-20-04-23` | - | - | RDS snapshot - a backup artifact, not infrastructure |
| X-backup | rds | `rds:migration-prod-2026-09-21-04-23` | - | - | RDS snapshot - a backup artifact, not infrastructure |
| X-backup | rds | `rds:migration-prod-2026-09-22-04-23` | - | - | RDS snapshot - a backup artifact, not infrastructure |
| X-backup | rds | `rds:migration-prod-2026-09-23-04-23` | - | - | RDS snapshot - a backup artifact, not infrastructure |
| X-cdk | cloudformation | `CDKToolkit/705944a0-4146-11f0-915c-0642b57525b5` | - | - | CloudFormation stack 'CDKToolkit/705944a0-4146-11f0-915c-0642b57525b5' - owned by whatever deployed it (CDK here) |
| X-cdk | cloudformation | `agrovesto-infra-deployment-agxdbRotationSingleUser48A10562-A75L3B7S0Q6S/773f42d0-c0ba-11f0-9aad-0a3b27a6ab6d` | - | - | CloudFormation stack 'agrovesto-infra-deployment-agxdbRotationSingleUser48A10562-A75L3B7S0Q6S/773f42d0-c0ba-11f0-9aad-0a3b27a6ab6d' - owned by whatever deployed it (CD... |
| X-cdk | cloudformation | `agrovesto-infra-deployment-nomaosdbRotationSingleUserE9E23701-1JE28HJLBB6CF/ea3388a0-c083-11f0-bc1a-06cb63262b17` | - | - | CloudFormation stack 'agrovesto-infra-deployment-nomaosdbRotationSingleUserE9E23701-1JE28HJLBB6CF/ea3388a0-c083-11f0-bc1a-06cb63262b17' - owned by whatever deployed it... |
| X-cdk | cloudformation | `agrovesto-infra-deployment/d1f77670-c083-11f0-bea9-0ac1d8e64f57` | - | - | CloudFormation stack 'agrovesto-infra-deployment/d1f77670-c083-11f0-bea9-0ac1d8e64f57' - owned by whatever deployed it (CDK here) |
| X-cdk | cloudformation | `agrovesto-infra-pipeline/0534fc00-4146-11f0-ade5-066133c06f59` | - | - | CloudFormation stack 'agrovesto-infra-pipeline/0534fc00-4146-11f0-ade5-066133c06f59' - owned by whatever deployed it (CDK here) |
| X-cdk | codebuild | `agrovesto-ProdCodeBuildProject` | - | - | created by the CDK pipeline stack agrovesto-infra-pipeline |
| X-cdk | codepipeline | `agrovesto-ProdPipeline` | - | - | created by the CDK pipeline stack agrovesto-infra-pipeline |
| X-cdk | codepipeline | `agrovesto-ProdWebhook` | - | - | created by the CDK pipeline stack agrovesto-infra-pipeline |
| X-cdk | ecr | `cdk-hnb659fds-container-assets-221434544570-eu-west-1` | - | - | CDK bootstrap container-asset repository |
| X-cdk | lambda | `agrovesto-infra-deploymen-CustomVpcRestrictDefault-IGFRSXLZxLMk` | - | - | CDK construct lambda (agrovesto-infra-deploymen-CustomVpcRestrictDefault-IGFRSXLZxLMk) - rewritten on every cdk deploy |
| X-cdk | lambda | `agrovestoinfradeploymentagxdbRotationSingleUser096353C8` | - | - | CDK construct lambda (agrovestoinfradeploymentagxdbRotationSingleUser096353C8) - rewritten on every cdk deploy |
| X-cdk | lambda | `agrovestoinfradeploymentnomaosdbRotationSingleUser77906076` | - | - | CDK construct lambda (agrovestoinfradeploymentnomaosdbRotationSingleUser77906076) - rewritten on every cdk deploy |
| X-cdk | logs | `/aws/lambda/agrovesto-infra-deploymen-CustomVpcRestrictDefault-HM2z7LXp0eJr` | - | - | log group of a CDK custom-resource lambda |
| X-cdk | logs | `/aws/lambda/agrovesto-infra-deploymen-CustomVpcRestrictDefault-IGFRSXLZxLMk` | - | - | log group of a CDK custom-resource lambda |
| X-cdk | logs | `/aws/lambda/agrovestoinfradeploymentagxdb2RotationSingleUserAF8581BB` | - | - | log group of a CDK custom-resource lambda |
| X-cdk | logs | `/aws/lambda/agrovestoinfradeploymentagxdbRotationSingleUser096353C8` | - | - | log group of a CDK custom-resource lambda |
| X-cdk | logs | `/aws/lambda/agrovestoinfradeploymentnomaosdbRotationSingleUser77906076` | - | - | log group of a CDK custom-resource lambda |
| X-cdk | rds | `agxdb2subnetgroup` | - | - | subnet group of a CDK-managed RDS instance |
| X-cdk | rds | `agxdbsubnetgroup` | - | - | subnet group of a CDK-managed RDS instance |
| X-cdk | rds | `nomaosdbsubnetgroup` | - | - | subnet group of a CDK-managed RDS instance |
| X-cdk | s3 | `cdk-hnb659fds-assets-221434544570-eu-west-1` | - | - | CDK bootstrap asset bucket |
| X-cdk | secretsmanager | `agxDBcredentials-C6MuaN` | - | - | CDK DatabaseSecret belonging to the CDK-managed RDS instance |
| X-cdk | secretsmanager | `nomaosDBcredentials-GIwHiK` | - | - | CDK DatabaseSecret belonging to the CDK-managed RDS instance |
| X-cdk | ssm | `cdk-bootstrap/hnb659fds/version` | - | - | CDK bootstrap version marker |
| X-derived | dms | `default-vpc-0016f521bae08f4ff` | - | - | the replication subnet group DMS creates automatically per VPC |
| X-derived | ec2 | `eni-02028b9c83fcafade` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-026166645623c9b77` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-03ef594208f601770` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-05d6d506568d9c7fa` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-0782d25d8f52831c9` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-084e099bdf7e5ab29` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-0a7399aa1ac96ded4` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-0b3f4c7c03c21ae97` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-0c6fc92cab00752e8` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `eni-0d8ecdba0a7e2cb6f` | - | - | ENI - created and owned by whatever it is attached to |
| X-derived | ec2 | `sgr-000034fe00141dd1c` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-001b82e11b77b4b4a` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-015641156ad857909` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-017ce4b359a4bd5ab` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0205ef31bcdc8fdf7` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0211adbd814ccf843` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-02495deebf5482b1d` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0296e076cee334729` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-03b1f4539ab6aedff` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-041c7e32dfda2e222` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-04252a8215498f164` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-042cad4bed9821063` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-04a07b1336fe3fb8e` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-04eda3d03370d3140` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0532d880b78ad901b` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-05d56972208df332a` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-062b3f926111ceb80` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-06d097bb211870643` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-06d1a92b39e7d6a20` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0746a5ba1408dcf1a` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-080063741123e3109` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-08d48fc7555a2f835` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-08e0df5882f784a24` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-096c61a122ec1a8a6` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-099f857e9e96fb901` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-09bf91a10e33fcd29` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-09dfc257fa3a3769c` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-09f08dd08bfffb966` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0a0850161748d27f8` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0a0b2fed11010b2fa` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0ac46beb19b5f3f97` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0bead8e587ed7419d` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0c12c5c6809684dbf` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0d25d4100adf6fcbf` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0d2ce6b7adb3714b8` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0d60a343f37842971` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0f04e32c55cba56bb` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | ec2 | `sgr-0f6d74ffe6a709dda` | - | - | one rule of a security group; Terraform models rules inside the group, so the group is the thing to import |
| X-derived | events | `amplify-d24hrz6o3pnmne-main-branch-notification` | - | - | created by Amplify for branch notifications |
| X-derived | lambda | `agrovesto-infra-deploymen-CustomVpcRestrictDefault-IGFRSXLZxLMk:$LATEST` | - | - | the $LATEST pseudo-version of a function; the function itself is the resource |
| X-derived | lambda | `agrovestoinfradeploymentagxdbRotationSingleUser096353C8:$LATEST` | - | - | the $LATEST pseudo-version of a function; the function itself is the resource |
| X-derived | lambda | `agrovestoinfradeploymentnomaosdbRotationSingleUser77906076:$LATEST` | - | - | the $LATEST pseudo-version of a function; the function itself is the resource |
| X-derived | sns | `amplify-d24hrz6o3pnmne_main` | - | - | created by Amplify for app branch notifications |
| X-derived | ssm | `i-027ff32f2a26fa600` | - | - | the SSM registration of EC2 instance i-027ff32f2a26fa600 - import the instance, not this |
| X-ephemeral | ssm | `NomaOS-f2furoj34ahtbbnihtxxqooy5u` | - | - | a Session Manager session - gone within minutes |
| X-tooling | resource-explorer-2 | `2375ed1a-7adc-44fe-a83f-4f9869bd659a` | - | - | Resource Explorer's own index - the tool that produced this inventory |
| X-tooling | resource-explorer-2 | `eu-west-1/1184df2b-d64b-48e3-85d6-4a7fe3110f8f` | - | - | Resource Explorer's own view - the tool that produced this inventory |
