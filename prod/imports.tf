# =============================================================================
# One-shot import blocks: adopt the existing AWS resources into this stack's
# state (see docs/import-runbook.md). After the first clean apply they are
# no-ops; delete this file once `terraform plan` shows "No changes".
# =============================================================================

# --- Adopted into the new design's addresses ---
import {
  to = aws_vpc.main
  id = "vpc-0016f521bae08f4ff"
}

import {
  to = aws_internet_gateway.main
  id = "igw-07275a1a62726a4c8"
}

# Public: the two IGW-routed subnets.
import {
  to = aws_subnet.public[0]
  id = "subnet-0b808deeaf8391867" # 172.96.0.0/24 eu-west-1a
}

import {
  to = aws_subnet.public[1]
  id = "subnet-0e169f40c70cdfe8b" # 172.96.1.0/24 eu-west-1b (noma-agx EC2)
}

# The existing public subnets each have their own route table. The design has
# ONE shared table: adopt rtb-0530… and re-point subnet-0e169… at it. The
# other table (rtb-0614…) is imported as legacy and can be deleted later.
import {
  to = aws_route_table.public
  id = "rtb-0530eb261b38f735b"
}

import {
  to = aws_route_table_association.public[0]
  id = "subnet-0b808deeaf8391867/rtb-0530eb261b38f735b"
}

# subnet-0e169… is associated with rtb-0614… today. Importing that association
# into public[1] makes the plan an in-place ReplaceRouteTableAssociation to
# rtb-0530…, which has the same IGW route, so there is no connectivity gap.
import {
  to = aws_route_table_association.public[1]
  id = "subnet-0e169f40c70cdfe8b/rtb-0614ed06de1bc1d89"
}

import {
  to = aws_route.public_internet
  id = "rtb-0530eb261b38f735b_0.0.0.0/0"
}

# Database: the two isolated subnets that migration-prod's subnet group
# (agxdb2subnetgroup) already uses. Adopting them keeps the instance in place.
import {
  to = aws_subnet.database[0]
  id = "subnet-00ee6901e53783c86" # 172.96.2.0/24 eu-west-1a
}

import {
  to = aws_subnet.database[1]
  id = "subnet-084f21457f316c44c" # 172.96.3.0/24 eu-west-1b
}

# Their route tables become the design's private tables. They gain the NAT
# route, and the new private subnets (172.96.11/12.0/24) share them.
import {
  to = aws_route_table.private[0]
  id = "rtb-0fa42099da11b78e9"
}

import {
  to = aws_route_table.private[1]
  id = "rtb-084528a52ec739f38"
}

import {
  to = aws_route_table_association.database[0]
  id = "subnet-00ee6901e53783c86/rtb-0fa42099da11b78e9"
}

import {
  to = aws_route_table_association.database[1]
  id = "subnet-084f21457f316c44c/rtb-084528a52ec739f38"
}

# --- DNS: both zones already exist -------------------------------------------
import {
  to = aws_route53_zone.this[0]
  id = "Z0208643NZ0W8WF5RQ9F" # nomaos.com
}

import {
  to = aws_route53_zone.agrovesto
  id = "Z00055662LTUSSMS5ZA84" # agrovesto.com
}

# --- RDS SQL Server: migration-prod -------------------------------------------
import {
  to = aws_db_instance.mssql
  id = "migration-prod"
}

import {
  to = aws_db_subnet_group.mssql
  id = "agxdb2subnetgroup"
}

# NOT adopted:
#  * ACM *.nomaos.com (5172b3e7…) has no apex SAN, and the design's cert needs
#    one, so the design creates a new cert. The old one is imported as legacy
#    (unused, delete later).
#  * The default SG sg-05a2722a… has 8 live rules and is attached to
#    migration-prod and the EC2 host, so it is imported as legacy, as-is
#    (manage_default_security_group = false).

# --- Legacy resources (config in legacy.tf) ---
import {
  to = aws_acm_certificate.legacy_cert_5172b3e7
  id = "arn:aws:acm:eu-west-1:221434544570:certificate/5172b3e7-972d-46c1-87f3-dc104934ac64"
}

# arn:aws:acm:eu-west-1:221434544570:certificate/f493b7d7-a3bb-4092-a2c9-54bd6655dbd1
# NOTE: if discover.sh shows *.nomaos.com + nomaos.com it can replace aws_acm_certificate.wildcard
import {
  to = aws_acm_certificate.legacy_cert_f493b7d7
  id = "arn:aws:acm:eu-west-1:221434544570:certificate/f493b7d7-a3bb-4092-a2c9-54bd6655dbd1"
}


# --- aws_amplify_app -------------------------------------------------------
# arn:aws:amplify:eu-west-1:221434544570:apps/d24hrz6o3pnmne
import {
  to = aws_amplify_app.legacy_d24hrz6o3pnmne
  id = "d24hrz6o3pnmne"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/d2qsjz4yzplkjb
import {
  to = aws_amplify_app.legacy_d2qsjz4yzplkjb
  id = "d2qsjz4yzplkjb"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/d2tux0dpg27k42
import {
  to = aws_amplify_app.legacy_d2tux0dpg27k42
  id = "d2tux0dpg27k42"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/d2uzc83ix5qdfu
import {
  to = aws_amplify_app.legacy_d2uzc83ix5qdfu
  id = "d2uzc83ix5qdfu"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/d3po2sm2zq4p71
import {
  to = aws_amplify_app.legacy_d3po2sm2zq4p71
  id = "d3po2sm2zq4p71"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/d4d246twq5d12
import {
  to = aws_amplify_app.legacy_d4d246twq5d12
  id = "d4d246twq5d12"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/dm0gdjrq9j06v
import {
  to = aws_amplify_app.legacy_dm0gdjrq9j06v
  id = "dm0gdjrq9j06v"
}


# --- aws_amplify_branch ----------------------------------------------------
# arn:aws:amplify:eu-west-1:221434544570:apps/d24hrz6o3pnmne/branches/master
import {
  to = aws_amplify_branch.legacy_d24hrz6o3pnmne_master
  id = "d24hrz6o3pnmne/master"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/d2qsjz4yzplkjb/branches/master
import {
  to = aws_amplify_branch.legacy_d2qsjz4yzplkjb_master
  id = "d2qsjz4yzplkjb/master"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/d2tux0dpg27k42/branches/master
import {
  to = aws_amplify_branch.legacy_d2tux0dpg27k42_master
  id = "d2tux0dpg27k42/master"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/d2uzc83ix5qdfu/branches/master
import {
  to = aws_amplify_branch.legacy_d2uzc83ix5qdfu_master
  id = "d2uzc83ix5qdfu/master"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/d3po2sm2zq4p71/branches/main
import {
  to = aws_amplify_branch.legacy_d3po2sm2zq4p71_main
  id = "d3po2sm2zq4p71/main"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/d4d246twq5d12/branches/master
import {
  to = aws_amplify_branch.legacy_d4d246twq5d12_master
  id = "d4d246twq5d12/master"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/dm0gdjrq9j06v/branches/master
import {
  to = aws_amplify_branch.legacy_dm0gdjrq9j06v_master
  id = "dm0gdjrq9j06v/master"
}


# --- aws_amplify_domain_association ----------------------------------------
# arn:aws:amplify:eu-west-1:221434544570:apps/d24hrz6o3pnmne/domains/agrovesto.com
import {
  to = aws_amplify_domain_association.legacy_d24hrz6o3pnmne_agrovesto_com
  id = "d24hrz6o3pnmne/agrovesto.com"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/d2qsjz4yzplkjb/domains/nomaos.com
import {
  to = aws_amplify_domain_association.legacy_d2qsjz4yzplkjb_nomaos_com
  id = "d2qsjz4yzplkjb/nomaos.com"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/d3po2sm2zq4p71/domains/trade.agrovesto.com
import {
  to = aws_amplify_domain_association.legacy_d3po2sm2zq4p71_trade_agrovesto_com
  id = "d3po2sm2zq4p71/trade.agrovesto.com"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/d4d246twq5d12/domains/insight.nomaos.com
import {
  to = aws_amplify_domain_association.legacy_d4d246twq5d12_insight_nomaos_com
  id = "d4d246twq5d12/insight.nomaos.com"
}

# arn:aws:amplify:eu-west-1:221434544570:apps/dm0gdjrq9j06v/domains/onboarding.nomaos.com
import {
  to = aws_amplify_domain_association.legacy_dm0gdjrq9j06v_onboarding_nomaos_com
  id = "dm0gdjrq9j06v/onboarding.nomaos.com"
}


# --- aws_cloudformation_stack ----------------------------------------------
# arn:aws:cloudformation:eu-west-1:221434544570:stack/agrovesto-infra-pipeline/0534fc00-4146-11f0-ade5-066133c06f59
# NOTE: Terraform owns the stack; its children are not imported separately
import {
  to = aws_cloudformation_stack.legacy_agrovesto_infra_pipeline
  id = "agrovesto-infra-pipeline"
}

# arn:aws:cloudformation:eu-west-1:221434544570:stack/CDKToolkit/705944a0-4146-11f0-915c-0642b57525b5
# NOTE: Terraform owns the stack; its children are not imported separately
import {
  to = aws_cloudformation_stack.legacy_cdktoolkit
  id = "CDKToolkit"
}


# --- aws_cloudwatch_event_rule ---------------------------------------------
# arn:aws:events:eu-west-1:221434544570:rule/amplify-d24hrz6o3pnmne-main-branch-notification
import {
  to = aws_cloudwatch_event_rule.legacy_amplify_d24hrz6o3pnmne_main_branch_notification
  id = "default/amplify-d24hrz6o3pnmne-main-branch-notification"
}


# --- aws_cloudwatch_log_group ----------------------------------------------
# arn:aws:logs:eu-west-1:221434544570:log-group:/aws/amplify/d3po2sm2zq4p71
import {
  to = aws_cloudwatch_log_group.legacy_aws_amplify_d3po2sm2zq4p71
  id = "/aws/amplify/d3po2sm2zq4p71"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:/aws/codebuild/agrovesto-ProdCodeBuildProject
import {
  to = aws_cloudwatch_log_group.legacy_aws_codebuild_agrovesto_prodcodebuildproject
  id = "/aws/codebuild/agrovesto-ProdCodeBuildProject"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:/aws/codepipeline/agreovesto-api
import {
  to = aws_cloudwatch_log_group.legacy_aws_codepipeline_agreovesto_api
  id = "/aws/codepipeline/agreovesto-api"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:/aws/codepipeline/Agx_Trade
import {
  to = aws_cloudwatch_log_group.legacy_aws_codepipeline_agx_trade
  id = "/aws/codepipeline/Agx_Trade"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:/aws/codepipeline/agxtrade
import {
  to = aws_cloudwatch_log_group.legacy_aws_codepipeline_agxtrade
  id = "/aws/codepipeline/agxtrade"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:/aws/codepipeline/argovesto-api-v8
import {
  to = aws_cloudwatch_log_group.legacy_aws_codepipeline_argovesto_api_v8
  id = "/aws/codepipeline/argovesto-api-v8"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:/aws/codepipeline/noma-api-new
import {
  to = aws_cloudwatch_log_group.legacy_aws_codepipeline_noma_api_new
  id = "/aws/codepipeline/noma-api-new"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:/aws/codepipeline/noma-api-pipeline
import {
  to = aws_cloudwatch_log_group.legacy_aws_codepipeline_noma_api_pipeline
  id = "/aws/codepipeline/noma-api-pipeline"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:/aws/codepipeline/noma-new
import {
  to = aws_cloudwatch_log_group.legacy_aws_codepipeline_noma_new
  id = "/aws/codepipeline/noma-new"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:/aws/lambda/agrovesto-infra-deploymen-CustomVpcRestrictDefault-HM2z7LXp0eJr
import {
  to = aws_cloudwatch_log_group.legacy_aws_lambda_agrovesto_infra_deploymen_customvpcrestrictdefaul
  id = "/aws/lambda/agrovesto-infra-deploymen-CustomVpcRestrictDefault-HM2z7LXp0eJr"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:/aws/lambda/agrovesto-infra-deploymen-CustomVpcRestrictDefault-IGFRSXLZxLMk
import {
  to = aws_cloudwatch_log_group.legacy_aws_lambda_agrovesto_infra_deploymen_customvpcrestrictdefaul_2
  id = "/aws/lambda/agrovesto-infra-deploymen-CustomVpcRestrictDefault-IGFRSXLZxLMk"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:/aws/lambda/agrovestoinfradeploymentagxdb2RotationSingleUserAF8581BB
import {
  to = aws_cloudwatch_log_group.legacy_aws_lambda_agrovestoinfradeploymentagxdb2rotationsingleusera
  id = "/aws/lambda/agrovestoinfradeploymentagxdb2RotationSingleUserAF8581BB"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:/aws/lambda/agrovestoinfradeploymentagxdbRotationSingleUser096353C8
import {
  to = aws_cloudwatch_log_group.legacy_aws_lambda_agrovestoinfradeploymentagxdbrotationsingleuser09
  id = "/aws/lambda/agrovestoinfradeploymentagxdbRotationSingleUser096353C8"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:/aws/lambda/agrovestoinfradeploymentnomaosdbRotationSingleUser77906076
import {
  to = aws_cloudwatch_log_group.legacy_aws_lambda_agrovestoinfradeploymentnomaosdbrotationsingleuse
  id = "/aws/lambda/agrovestoinfradeploymentnomaosdbRotationSingleUser77906076"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:/aws/rds/instance/migration-prod/error
import {
  to = aws_cloudwatch_log_group.legacy_aws_rds_instance_migration_prod_error
  id = "/aws/rds/instance/migration-prod/error"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:dms-serverless-replication-agx
import {
  to = aws_cloudwatch_log_group.legacy_dms_serverless_replication_agx
  id = "dms-serverless-replication-agx"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:dms-serverless-replication-nomaos
import {
  to = aws_cloudwatch_log_group.legacy_dms_serverless_replication_nomaos
  id = "dms-serverless-replication-nomaos"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:noma-api
import {
  to = aws_cloudwatch_log_group.legacy_noma_api
  id = "noma-api"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:/nomaos/prod/api
import {
  to = aws_cloudwatch_log_group.legacy_nomaos_prod_api
  id = "/nomaos/prod/api"
}


# --- aws_codeconnections_connection ----------------------------------------
# arn:aws:codeconnections:eu-west-1:221434544570:connection/da07fb91-02f9-4552-9d01-837a9366b681
import {
  to = aws_codeconnections_connection.legacy_conn_da07fb91
  id = "arn:aws:codeconnections:eu-west-1:221434544570:connection/da07fb91-02f9-4552-9d01-837a9366b681"
}


# --- aws_codepipeline ------------------------------------------------------
# arn:aws:codepipeline:eu-west-1:221434544570:Agx_Trade
import {
  to = aws_codepipeline.legacy_agx_trade
  id = "Agx_Trade"
}

# arn:aws:codepipeline:eu-west-1:221434544570:noma-api-pipeline
import {
  to = aws_codepipeline.legacy_noma_api_pipeline
  id = "noma-api-pipeline"
}

# arn:aws:codepipeline:eu-west-1:221434544570:noma-new
import {
  to = aws_codepipeline.legacy_noma_new
  id = "noma-new"
}


# --- aws_codestarconnections_connection ------------------------------------
# arn:aws:codestar-connections:eu-west-1:221434544570:connection/54bd9bd5-955a-4415-873e-aa936036f835
import {
  to = aws_codestarconnections_connection.legacy_conn_54bd9bd5
  id = "arn:aws:codestar-connections:eu-west-1:221434544570:connection/54bd9bd5-955a-4415-873e-aa936036f835"
}


# --- aws_db_subnet_group ---------------------------------------------------
# arn:aws:rds:eu-west-1:221434544570:subgrp:agxdbsubnetgroup
# NOTE: if this is migration-prod's subnet group, use the aws_db_subnet_group.mssql slot in imports_adopt.tf instead
import {
  to = aws_db_subnet_group.legacy_agxdbsubnetgroup
  id = "agxdbsubnetgroup"
}

# arn:aws:rds:eu-west-1:221434544570:subgrp:nomaosdbsubnetgroup
# NOTE: if this is migration-prod's subnet group, use the aws_db_subnet_group.mssql slot in imports_adopt.tf instead
import {
  to = aws_db_subnet_group.legacy_nomaosdbsubnetgroup
  id = "nomaosdbsubnetgroup"
}


# --- aws_default_network_acl -----------------------------------------------
# arn:aws:ec2:eu-west-1:221434544570:network-acl/acl-06b37d7639de1e948
# NOTE: the VPC's default NACL; generated config must list its subnet_ids
import {
  to = aws_default_network_acl.legacy_acl_06b37d7639de1e948
  id = "acl-06b37d7639de1e948"
}


# --- aws_default_route_table -----------------------------------------------
# arn:aws:ec2:eu-west-1:221434544570:route-table/rtb-0fa0841a7b7dac5db
# NOTE: the VPC's main route table (no subnets associated)
import {
  to = aws_default_route_table.legacy_main_rtb_0fa0841a7b7dac5db
  id = "vpc-0016f521bae08f4ff"
}


# --- aws_default_security_group --------------------------------------------
# arn:aws:ec2:eu-west-1:221434544570:security-group/sg-05a2722a050c1109b
# NOTE: default SG with LIVE rules (attached to migration-prod + EC2): kept as-is, manage_default_security_group = false
import {
  to = aws_default_security_group.legacy_default
  id = "sg-05a2722a050c1109b"
}


# --- aws_dms_endpoint ------------------------------------------------------
# arn:aws:dms:eu-west-1:221434544570:endpoint:agxdb
# NOTE: password is write-only: never read into state; keep it in Secrets Manager (secrets_manager_arn)
import {
  to = aws_dms_endpoint.legacy_agxdb2instance
  id = "agxdb2instance"
}

# arn:aws:dms:eu-west-1:221434544570:endpoint:WFZ6YQ2JCJBLLBLRDLCH7XNRWY
# NOTE: password is write-only: never read into state; keep it in Secrets Manager (secrets_manager_arn)
import {
  to = aws_dms_endpoint.legacy_agxdb_snapshot_restore
  id = "agxdb-snapshot-restore"
}

# arn:aws:dms:eu-west-1:221434544570:endpoint:BSI5NFYJSVELZMYVPFOMJ56MIM
# NOTE: password is write-only: never read into state; keep it in Secrets Manager (secrets_manager_arn)
import {
  to = aws_dms_endpoint.legacy_nomaosdbinstance
  id = "nomaosdbinstance"
}

# arn:aws:dms:eu-west-1:221434544570:endpoint:nomaos
# NOTE: password is write-only: never read into state; keep it in Secrets Manager (secrets_manager_arn)
import {
  to = aws_dms_endpoint.legacy_nomaosinstance_snapshot_restore
  id = "nomaosinstance-snapshot-restore"
}


# --- aws_dms_replication_subnet_group --------------------------------------
# arn:aws:dms:eu-west-1:221434544570:subgrp:default-vpc-0016f521bae08f4ff
import {
  to = aws_dms_replication_subnet_group.legacy_default_vpc_0016f521bae08f4ff
  id = "default-vpc-0016f521bae08f4ff"
}


# --- aws_eip ---------------------------------------------------------------
# arn:aws:ec2:eu-west-1:221434544570:elastic-ip/eipalloc-0a48ffb921e22bb39
import {
  to = aws_eip.legacy_eipalloc_0a48ffb921e22bb39
  id = "eipalloc-0a48ffb921e22bb39"
}


# --- aws_instance ----------------------------------------------------------
# arn:aws:ec2:eu-west-1:221434544570:instance/i-027ff32f2a26fa600
import {
  to = aws_instance.legacy_i_027ff32f2a26fa600
  id = "i-027ff32f2a26fa600"
}


# --- aws_key_pair ----------------------------------------------------------
# arn:aws:ec2:eu-west-1:221434544570:key-pair/key-0b6382b8152c63533
# NOTE: public key material only; add lifecycle ignore_changes = [public_key]
import {
  to = aws_key_pair.legacy_deployment_ssh
  id = "deployment-ssh"
}

# arn:aws:ec2:eu-west-1:221434544570:key-pair/key-075e7652029e2c2c5
# NOTE: public key material only; add lifecycle ignore_changes = [public_key]
import {
  to = aws_key_pair.legacy_noma_agx
  id = "noma-agx"
}

# arn:aws:ec2:eu-west-1:221434544570:key-pair/key-057e0d6c32eb78e4d
# NOTE: public key material only; add lifecycle ignore_changes = [public_key]
import {
  to = aws_key_pair.legacy_rdsjumpserverkeypair
  id = "rdsjumpserverkeypair"
}


# --- aws_lambda_function ---------------------------------------------------
# arn:aws:lambda:eu-west-1:221434544570:function:agrovesto-infra-deploymen-CustomVpcRestrictDefault-IGFRSXLZxLMk
import {
  to = aws_lambda_function.legacy_agrovesto_infra_deploymen_customvpcrestrictdefault_igfrsxlzx
  id = "agrovesto-infra-deploymen-CustomVpcRestrictDefault-IGFRSXLZxLMk"
}

# arn:aws:lambda:eu-west-1:221434544570:function:agrovestoinfradeploymentagxdbRotationSingleUser096353C8
import {
  to = aws_lambda_function.legacy_agrovestoinfradeploymentagxdbrotationsingleuser096353c8
  id = "agrovestoinfradeploymentagxdbRotationSingleUser096353C8"
}

# arn:aws:lambda:eu-west-1:221434544570:function:agrovestoinfradeploymentnomaosdbRotationSingleUser77906076
import {
  to = aws_lambda_function.legacy_agrovestoinfradeploymentnomaosdbrotationsingleuser77906076
  id = "agrovestoinfradeploymentnomaosdbRotationSingleUser77906076"
}


# --- aws_launch_template ---------------------------------------------------
# arn:aws:ec2:eu-west-1:221434544570:launch-template/lt-017de20e61da8fe44
import {
  to = aws_launch_template.legacy_lt_017de20e61da8fe44
  id = "lt-017de20e61da8fe44"
}

# arn:aws:ec2:eu-west-1:221434544570:launch-template/lt-08897dce459b4913c
import {
  to = aws_launch_template.legacy_lt_08897dce459b4913c
  id = "lt-08897dce459b4913c"
}


# --- aws_resourceexplorer2_index -------------------------------------------
# arn:aws:resource-explorer-2:eu-west-1:221434544570:index/2375ed1a-7adc-44fe-a83f-4f9869bd659a
import {
  to = aws_resourceexplorer2_index.legacy_index
  id = "arn:aws:resource-explorer-2:eu-west-1:221434544570:index/2375ed1a-7adc-44fe-a83f-4f9869bd659a"
}


# --- aws_resourceexplorer2_view --------------------------------------------
# arn:aws:resource-explorer-2:eu-west-1:221434544570:view/eu-west-1/1184df2b-d64b-48e3-85d6-4a7fe3110f8f
import {
  to = aws_resourceexplorer2_view.legacy_view
  id = "arn:aws:resource-explorer-2:eu-west-1:221434544570:view/eu-west-1/1184df2b-d64b-48e3-85d6-4a7fe3110f8f"
}


# --- aws_route_table -------------------------------------------------------
# arn:aws:ec2:eu-west-1:221434544570:route-table/rtb-0614ed06de1bc1d89
# NOTE: not used by the new design; review for deletion after cut-over
import {
  to = aws_route_table.legacy_rtb_0614ed06de1bc1d89
  id = "rtb-0614ed06de1bc1d89"
}


# --- aws_s3_bucket ---------------------------------------------------------
# arn:aws:s3:::agrovesto-pipeline-artifacts
import {
  to = aws_s3_bucket.legacy_agrovesto_pipeline_artifacts
  id = "agrovesto-pipeline-artifacts"
}

# arn:aws:s3:::agrovesto-storage
import {
  to = aws_s3_bucket.legacy_agrovesto_storage
  id = "agrovesto-storage"
}

# arn:aws:s3:::cf-templates-lh5u9ipyvd5c-eu-west-1
import {
  to = aws_s3_bucket.legacy_cf_templates_lh5u9ipyvd5c_eu_west_1
  id = "cf-templates-lh5u9ipyvd5c-eu-west-1"
}

# arn:aws:s3:::codepipeline-eu-west-1-388c27815165-4d9c-97e5-35f4ec8ad1d6
import {
  to = aws_s3_bucket.legacy_codepipeline_eu_west_1_388c27815165_4d9c_97e5_35f4ec8ad1d6
  id = "codepipeline-eu-west-1-388c27815165-4d9c-97e5-35f4ec8ad1d6"
}

# arn:aws:s3:::dms-serverless-premigration-results-dnwcx6llcg
import {
  to = aws_s3_bucket.legacy_dms_serverless_premigration_results_dnwcx6llcg
  id = "dms-serverless-premigration-results-dnwcx6llcg"
}


# --- aws_secretsmanager_secret ---------------------------------------------
# arn:aws:secretsmanager:eu-west-1:221434544570:secret:agxDBcredentials-C6MuaN
# NOTE: secret metadata only - no aws_secretsmanager_secret_version, so no secret value enters state
import {
  to = aws_secretsmanager_secret.legacy_agxdbcredentials
  id = "arn:aws:secretsmanager:eu-west-1:221434544570:secret:agxDBcredentials-C6MuaN"
}

# arn:aws:secretsmanager:eu-west-1:221434544570:secret:nomaosDBcredentials-GIwHiK
# NOTE: secret metadata only - no aws_secretsmanager_secret_version, so no secret value enters state
import {
  to = aws_secretsmanager_secret.legacy_nomaosdbcredentials
  id = "arn:aws:secretsmanager:eu-west-1:221434544570:secret:nomaosDBcredentials-GIwHiK"
}


# --- aws_security_group ----------------------------------------------------
# arn:aws:ec2:eu-west-1:221434544570:security-group/sg-0121823b5aba80621
import {
  to = aws_security_group.legacy_sg_0121823b5aba80621
  id = "sg-0121823b5aba80621"
}

# arn:aws:ec2:eu-west-1:221434544570:security-group/sg-044858bb412fc2aa0
import {
  to = aws_security_group.legacy_sg_044858bb412fc2aa0
  id = "sg-044858bb412fc2aa0"
}

# arn:aws:ec2:eu-west-1:221434544570:security-group/sg-04778d7bdb8e2c026
import {
  to = aws_security_group.legacy_sg_04778d7bdb8e2c026
  id = "sg-04778d7bdb8e2c026"
}

# arn:aws:ec2:eu-west-1:221434544570:security-group/sg-06e44543a37f56828
import {
  to = aws_security_group.legacy_sg_06e44543a37f56828
  id = "sg-06e44543a37f56828"
}

# arn:aws:ec2:eu-west-1:221434544570:security-group/sg-072ebb62525423c86
import {
  to = aws_security_group.legacy_sg_072ebb62525423c86
  id = "sg-072ebb62525423c86"
}

# arn:aws:ec2:eu-west-1:221434544570:security-group/sg-094939b554d597e4a
import {
  to = aws_security_group.legacy_sg_094939b554d597e4a
  id = "sg-094939b554d597e4a"
}

# arn:aws:ec2:eu-west-1:221434544570:security-group/sg-09e61cfd83551d0ec
import {
  to = aws_security_group.legacy_sg_09e61cfd83551d0ec
  id = "sg-09e61cfd83551d0ec"
}

# arn:aws:ec2:eu-west-1:221434544570:security-group/sg-0b555edfc6d445a18
import {
  to = aws_security_group.legacy_sg_0b555edfc6d445a18
  id = "sg-0b555edfc6d445a18"
}

# arn:aws:ec2:eu-west-1:221434544570:security-group/sg-0bfbddac52a0a2b89
import {
  to = aws_security_group.legacy_sg_0bfbddac52a0a2b89
  id = "sg-0bfbddac52a0a2b89"
}

# arn:aws:ec2:eu-west-1:221434544570:security-group/sg-0df9c118433af39dd
import {
  to = aws_security_group.legacy_sg_0df9c118433af39dd
  id = "sg-0df9c118433af39dd"
}

# arn:aws:ec2:eu-west-1:221434544570:security-group/sg-0e4ef41f521e66695
import {
  to = aws_security_group.legacy_sg_0e4ef41f521e66695
  id = "sg-0e4ef41f521e66695"
}

# arn:aws:ec2:eu-west-1:221434544570:security-group/sg-0f208f7733ec29fbd
import {
  to = aws_security_group.legacy_sg_0f208f7733ec29fbd
  id = "sg-0f208f7733ec29fbd"
}


# --- aws_sesv2_configuration_set -------------------------------------------
# arn:aws:ses:eu-west-1:221434544570:configuration-set/my-first-configuration-set
import {
  to = aws_sesv2_configuration_set.legacy_my_first_configuration_set
  id = "my-first-configuration-set"
}


# --- aws_sesv2_email_identity ----------------------------------------------
# arn:aws:ses:eu-west-1:221434544570:identity/agrovesto.com
# NOTE: domain identity
import {
  to = aws_sesv2_email_identity.legacy_agrovesto_com
  id = "agrovesto.com"
}

# arn:aws:ses:eu-west-1:221434544570:identity/info@agrovesto.com
import {
  to = aws_sesv2_email_identity.legacy_info_agrovesto_com
  id = "info@agrovesto.com"
}

# arn:aws:ses:eu-west-1:221434544570:identity/tech@agrovesto.com
import {
  to = aws_sesv2_email_identity.legacy_tech_agrovesto_com
  id = "tech@agrovesto.com"
}


# --- aws_sns_topic ---------------------------------------------------------
# arn:aws:sns:eu-west-1:221434544570:agrovesto
import {
  to = aws_sns_topic.legacy_agrovesto
  id = "arn:aws:sns:eu-west-1:221434544570:agrovesto"
}

# arn:aws:sns:eu-west-1:221434544570:amplify-d24hrz6o3pnmne_main
import {
  to = aws_sns_topic.legacy_amplify_d24hrz6o3pnmne_main
  id = "arn:aws:sns:eu-west-1:221434544570:amplify-d24hrz6o3pnmne_main"
}
