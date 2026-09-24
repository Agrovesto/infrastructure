# # __generated__ by Terraform
# # Please review these resources and move them into your main configuration files.

# # __generated__ by Terraform from "dfvk5chhp2iln/dev.nomaos.com"
# resource "aws_amplify_domain_association" "legacy_dfvk5chhp2iln_dev_nomaos_com" {
#   app_id                 = "dfvk5chhp2iln"
#   domain_name            = "dev.nomaos.com"
#   enable_auto_sub_domain = false
#   wait_for_verification  = null
#   certificate_settings {
#     custom_certificate_arn = null
#     type                   = "AMPLIFY_MANAGED"
#   }
#   sub_domain {
#     branch_name = "staging"
#     prefix      = ""
#   }
#   sub_domain {
#     branch_name = "staging"
#     prefix      = "www"
#   }
# }

# # __generated__ by Terraform from "d83we1jws50dz"
# resource "aws_amplify_app" "legacy_d83we1jws50dz" {
#   access_token                  = null # sensitive
#   auto_branch_creation_patterns = []
#   basic_auth_credentials        = null # sensitive
#   build_spec                    = "version: 1\nfrontend:\n  phases:\n    preBuild:\n      commands:\n        - npm ci --cache .npm --prefer-offline\n    build:\n      commands:\n        - npm run build\n  artifacts:\n    baseDirectory: .next\n    files:\n      - '**/*'\n  cache:\n    paths:\n      - .next/cache/**/*\n      - .npm/**/*\n"
#   compute_role_arn              = null
#   custom_headers                = null
#   description                   = null
#   enable_auto_branch_creation   = false
#   enable_basic_auth             = false
#   enable_branch_auto_build      = false
#   enable_branch_auto_deletion   = false
#   environment_variables         = {}
#   iam_service_role_arn          = "arn:aws:iam::353833416626:role/service-role/AmplifySSRLoggingRole-702a70a4-375c-468f-97d4-4641dd448284"
#   name                          = "tradeplatform"
#   oauth_token                   = null # sensitive
#   platform                      = "WEB_COMPUTE"
#   repository                    = "https://github.com/Agrovesto/tradeplatform"
#   tags                          = {}
#   tags_all                      = {}
#   cache_config {
#     type = "AMPLIFY_MANAGED_NO_COOKIES"
#   }
#   custom_rule {
#     condition = null
#     source    = "/<*>"
#     status    = "404-200"
#     target    = "/index.html"
#   }
# }

# # __generated__ by Terraform from "d1grwi75us24mx/dev-insight.nomaos.com"
# resource "aws_amplify_domain_association" "legacy_d1grwi75us24mx_dev_insight_nomaos_com" {
#   app_id                 = "d1grwi75us24mx"
#   domain_name            = "dev-insight.nomaos.com"
#   enable_auto_sub_domain = false
#   wait_for_verification  = null
#   certificate_settings {
#     custom_certificate_arn = null
#     type                   = "AMPLIFY_MANAGED"
#   }
#   sub_domain {
#     branch_name = "staging"
#     prefix      = ""
#   }
#   sub_domain {
#     branch_name = "staging"
#     prefix      = "www"
#   }
# }

# # __generated__ by Terraform from "d3v79u00ot9glq/dev-onboarding.nomaos.com"
# resource "aws_amplify_domain_association" "legacy_d3v79u00ot9glq_dev_onboarding_nomaos_com" {
#   app_id                 = "d3v79u00ot9glq"
#   domain_name            = "dev-onboarding.nomaos.com"
#   enable_auto_sub_domain = false
#   wait_for_verification  = null
#   certificate_settings {
#     custom_certificate_arn = null
#     type                   = "AMPLIFY_MANAGED"
#   }
#   sub_domain {
#     branch_name = "dev"
#     prefix      = ""
#   }
#   sub_domain {
#     branch_name = "dev"
#     prefix      = "www"
#   }
# }

# # __generated__ by Terraform from "/aws/rds/instance/nomaos/error"
# resource "aws_cloudwatch_log_group" "legacy_aws_rds_instance_nomaos_error" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/rds/instance/nomaos/error"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "/aws/codepipeline/nomaos"
# resource "aws_cloudwatch_log_group" "legacy_aws_codepipeline_nomaos" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/codepipeline/nomaos"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "arn:aws:codeconnections:eu-west-1:353833416626:connection/34fe4280-df27-43a0-b239-95a71c4c1d9b"
# resource "aws_codeconnections_connection" "legacy_conn_34fe4280" {
#   host_arn      = null
#   name          = "Agrovesto"
#   provider_type = "GitHub"
#   tags          = null
# }

# # __generated__ by Terraform from "/nomaos/prod/api"
# resource "aws_cloudwatch_log_group" "legacy_nomaos_prod_api" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/nomaos/prod/api"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "ec2-syslog"
# resource "aws_cloudwatch_log_group" "legacy_ec2_syslog" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "ec2-syslog"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "/agx/staging/api"
# resource "aws_cloudwatch_log_group" "legacy_agx_staging_api" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/agx/staging/api"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "/aws/amplify/d83we1jws50dz"
# resource "aws_cloudwatch_log_group" "legacy_aws_amplify_d83we1jws50dz" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/amplify/d83we1jws50dz"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "Z04841994LNF5EA00ZEG"
# resource "aws_route53_zone" "legacy_dev_nomaos_com" {
#   comment           = null
#   delegation_set_id = null
#   force_destroy     = null
#   name              = "dev.nomaos.com"
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "d83we1jws50dz/staging"
# resource "aws_amplify_branch" "legacy_d83we1jws50dz_staging" {
#   app_id                        = "d83we1jws50dz"
#   backend_environment_arn       = null
#   basic_auth_credentials        = null # sensitive
#   branch_name                   = "staging"
#   description                   = null
#   display_name                  = "staging"
#   enable_auto_build             = true
#   enable_basic_auth             = false
#   enable_notification           = false
#   enable_performance_mode       = false
#   enable_pull_request_preview   = false
#   environment_variables         = {}
#   framework                     = "Next.js - SSR"
#   pull_request_environment_name = null
#   stage                         = "PRODUCTION"
#   tags                          = {}
#   tags_all                      = {}
#   ttl                           = jsonencode(5)
# }

# # __generated__ by Terraform from "acl-0ac9d68464b5edd0a"
# resource "aws_default_network_acl" "legacy_acl_0ac9d68464b5edd0a" {
#   default_network_acl_id = "acl-0ac9d68464b5edd0a"
#   subnet_ids             = ["subnet-004a7f9d9cbd53ea4", "subnet-0304d72cd90dd43d9", "subnet-0309fc43ea380ad6b", "subnet-0739cfd4c412deb3f"]
#   tags                   = {}
#   tags_all               = {}
#   egress {
#     action          = "allow"
#     cidr_block      = "0.0.0.0/0"
#     from_port       = 0
#     icmp_code       = 0
#     icmp_type       = 0
#     ipv6_cidr_block = null
#     protocol        = jsonencode(-1)
#     rule_no         = 100
#     to_port         = 0
#   }
#   ingress {
#     action          = "allow"
#     cidr_block      = "0.0.0.0/0"
#     from_port       = 0
#     icmp_code       = 0
#     icmp_type       = 0
#     ipv6_cidr_block = null
#     protocol        = jsonencode(-1)
#     rule_no         = 100
#     to_port         = 0
#   }
# }

# # __generated__ by Terraform from "/aws/rds/instance/nomaosdbinstance/error"
# resource "aws_cloudwatch_log_group" "legacy_aws_rds_instance_nomaosdbinstance_error" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/rds/instance/nomaosdbinstance/error"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "/aws/lambda/amplify-reactvitetailwind-CustomS3AutoDeleteObject-E8AAR8n4318u"
# resource "aws_cloudwatch_log_group" "legacy_aws_lambda_amplify_reactvitetailwind_customs3autodeleteobjec" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/lambda/amplify-reactvitetailwind-CustomS3AutoDeleteObject-E8AAR8n4318u"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "/aws/lambda/amplify-reactvitetailwind-CustomCDKBucketDeploymen-VfnRjrAwAUEB"
# resource "aws_cloudwatch_log_group" "legacy_aws_lambda_amplify_reactvitetailwind_customcdkbucketdeployme" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/lambda/amplify-reactvitetailwind-CustomCDKBucketDeploymen-VfnRjrAwAUEB"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "/aws/lambda/agrovesto-infra-deploymen-CustomVpcRestrictDefault-nZX8uP3WCqzp"
# resource "aws_cloudwatch_log_group" "legacy_aws_lambda_agrovesto_infra_deploymen_customvpcrestrictdefaul_2" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/lambda/agrovesto-infra-deploymen-CustomVpcRestrictDefault-nZX8uP3WCqzp"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform
# resource "aws_subnet" "legacy_subnet_004a7f9d9cbd53ea4" {
#   assign_ipv6_address_on_creation                = false
#   availability_zone                              = "eu-west-1b"
#   availability_zone_id                           = "euw1-az3"
#   cidr_block                                     = "172.96.3.0/24"
#   customer_owned_ipv4_pool                       = null
#   enable_dns64                                   = false
#   enable_lni_at_device_index                     = 0
#   enable_resource_name_dns_a_record_on_launch    = false
#   enable_resource_name_dns_aaaa_record_on_launch = false
#   ipv6_cidr_block                                = null
#   ipv6_native                                    = false
#   map_customer_owned_ip_on_launch                = false
#   map_public_ip_on_launch                        = false
#   outpost_arn                                    = null
#   private_dns_hostname_type_on_launch            = "ip-name"
#   tags = {
#     Name                  = "agrovesto-infra-deployment/agrovesto-vpc/privateSubnet2"
#     "aws-cdk:subnet-name" = "private"
#     "aws-cdk:subnet-type" = "Private"
#   }
#   tags_all = {
#     Name                  = "agrovesto-infra-deployment/agrovesto-vpc/privateSubnet2"
#     "aws-cdk:subnet-name" = "private"
#     "aws-cdk:subnet-type" = "Private"
#   }
#   vpc_id = "vpc-0d9b566c353787d53"
# }

# # __generated__ by Terraform
# resource "aws_lambda_function" "legacy_agrovesto_infra_deploymen_customvpcrestrictdefault_nzx8up3wc" {
#   architectures                      = ["x86_64"]
#   code_signing_config_arn            = null
#   description                        = "Lambda function for removing all inbound/outbound rules from the VPC default security group"
#   filename                           = "legacy_lambda_placeholder.zip"
#   function_name                      = "agrovesto-infra-deploymen-CustomVpcRestrictDefault-nZX8uP3WCqzp"
#   handler                            = "__entrypoint__.handler"
#   image_uri                          = null
#   kms_key_arn                        = null
#   layers                             = []
#   memory_size                        = 128
#   package_type                       = "Zip"
#   publish                            = null
#   replace_security_groups_on_destroy = null
#   replacement_security_group_ids     = null
#   reserved_concurrent_executions     = -1
#   role                               = "arn:aws:iam::353833416626:role/agrovesto-infra-deploymen-CustomVpcRestrictDefaultS-wHppFzTSRAd1"
#   runtime                            = "nodejs22.x"
#   s3_bucket                          = null
#   s3_key                             = null
#   s3_object_version                  = null
#   skip_destroy                       = false
#   source_code_hash                   = null
#   tags                               = {}
#   tags_all                           = {}
#   timeout                            = 900
#   ephemeral_storage {
#     size = 512
#   }
#   logging_config {
#     application_log_level = null
#     log_format            = "Text"
#     log_group             = "/aws/lambda/agrovesto-infra-deploymen-CustomVpcRestrictDefault-nZX8uP3WCqzp"
#     system_log_level      = null
#   }
#   tracing_config {
#     mode = "PassThrough"
#   }
#   lifecycle {
#     ignore_changes = [filename, source_code_hash]
#   }
# }

# # __generated__ by Terraform from "vpc-0d9b566c353787d53"
# resource "aws_default_route_table" "legacy_main_rtb_0faede26619f355d8" {
#   default_route_table_id = "rtb-0faede26619f355d8"
#   propagating_vgws       = []
#   route                  = []
#   tags                   = {}
#   tags_all               = {}
# }

# # __generated__ by Terraform from "subnet-0304d72cd90dd43d9/rtb-04a4e32b4443f50d5"
# resource "aws_route_table_association" "legacy_subnet_0304d72cd90dd43d9" {
#   gateway_id     = null
#   route_table_id = "rtb-04a4e32b4443f50d5"
#   subnet_id      = "subnet-0304d72cd90dd43d9"
# }

# # __generated__ by Terraform from "subnet-0309fc43ea380ad6b/rtb-05817e82c2f16f0a4"
# resource "aws_route_table_association" "legacy_subnet_0309fc43ea380ad6b" {
#   gateway_id     = null
#   route_table_id = "rtb-05817e82c2f16f0a4"
#   subnet_id      = "subnet-0309fc43ea380ad6b"
# }

# # __generated__ by Terraform from "d1grwi75us24mx/staging"
# resource "aws_amplify_branch" "legacy_d1grwi75us24mx_staging" {
#   app_id                        = "d1grwi75us24mx"
#   backend_environment_arn       = null
#   basic_auth_credentials        = null # sensitive
#   branch_name                   = "staging"
#   description                   = null
#   display_name                  = "staging"
#   enable_auto_build             = true
#   enable_basic_auth             = false
#   enable_notification           = false
#   enable_performance_mode       = false
#   enable_pull_request_preview   = false
#   environment_variables         = {}
#   framework                     = "Web"
#   pull_request_environment_name = null
#   stage                         = "PRODUCTION"
#   tags                          = {}
#   tags_all                      = {}
#   ttl                           = jsonencode(5)
# }

# # __generated__ by Terraform from "sg-0d8184650fd775043"
# resource "aws_security_group" "legacy_sg_0d8184650fd775043" {
#   description = "Security group attached to instances to securely connect to nomaosdbinstance. Modification could lead to connection loss."
#   egress = [{
#     cidr_blocks      = []
#     description      = "Rule to allow connections to nomaosdbinstance from any instances this security group is attached to"
#     from_port        = 1433
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = ["sg-0c4d118c6776629d9"]
#     self             = false
#     to_port          = 1433
#   }]
#   ingress                = []
#   name                   = "ec2-rds-2"
#   name_prefix            = null
#   revoke_rules_on_delete = null
#   tags                   = {}
#   tags_all               = {}
#   vpc_id                 = "vpc-0d9b566c353787d53"
# }

# # __generated__ by Terraform from "/aws/lambda/agrovestoinfradeploymentagxdbRotationSingleUser096353C8"
# resource "aws_cloudwatch_log_group" "legacy_aws_lambda_agrovestoinfradeploymentagxdbrotationsingleuser09" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/lambda/agrovestoinfradeploymentagxdbRotationSingleUser096353C8"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "/aws/lambda/amplify-reactvitetailwind-TableManagerCustomProvid-ueZTCRxhdAWz"
# resource "aws_cloudwatch_log_group" "legacy_aws_lambda_amplify_reactvitetailwind_tablemanagercustomprovi_2" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/lambda/amplify-reactvitetailwind-TableManagerCustomProvid-ueZTCRxhdAWz"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "ami-0fd912de0c8674a38"
# resource "aws_ami" "legacy_ami_0fd912de0c8674a38" {
#   architecture        = "x86_64"
#   boot_mode           = "uefi-preferred"
#   deprecation_time    = null
#   description         = null
#   ena_support         = true
#   image_location      = "353833416626/dev-env"
#   imds_support        = null
#   kernel_id           = null
#   name                = "dev-env"
#   ramdisk_id          = null
#   root_device_name    = "/dev/sda1"
#   sriov_net_support   = "simple"
#   tags                = {}
#   tags_all            = {}
#   tpm_support         = null
#   uefi_data           = null
#   virtualization_type = "hvm"
#   ebs_block_device {
#     delete_on_termination = true
#     device_name           = "/dev/sda1"
#     encrypted             = false
#     iops                  = 0
#     outpost_arn           = null
#     snapshot_id           = "snap-02bcd30dd064d2166"
#     throughput            = 0
#     volume_size           = 500
#     volume_type           = "gp2"
#   }
#   ephemeral_block_device {
#     device_name  = "/dev/sdb"
#     virtual_name = "ephemeral0"
#   }
#   ephemeral_block_device {
#     device_name  = "/dev/sdc"
#     virtual_name = "ephemeral1"
#   }
# }

# # __generated__ by Terraform from "/aws/rds/instance/agxdbinstance/error"
# resource "aws_cloudwatch_log_group" "legacy_aws_rds_instance_agxdbinstance_error" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/rds/instance/agxdbinstance/error"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform
# resource "aws_route_table" "legacy_rtb_05817e82c2f16f0a4" {
#   propagating_vgws = []
#   route = [{
#     carrier_gateway_id         = null
#     cidr_block                 = "0.0.0.0/0"
#     core_network_arn           = null
#     destination_prefix_list_id = null
#     egress_only_gateway_id     = null
#     gateway_id                 = "igw-04e4d65d903b2b67d"
#     ipv6_cidr_block            = null
#     local_gateway_id           = null
#     nat_gateway_id             = null
#     network_interface_id       = null
#     transit_gateway_id         = null
#     vpc_endpoint_id            = null
#     vpc_peering_connection_id  = null
#   }]
#   tags = {
#     Name = "agrovesto-infra-deployment/agrovesto-vpc/publicSubnet2"
#   }
#   tags_all = {
#     Name = "agrovesto-infra-deployment/agrovesto-vpc/publicSubnet2"
#   }
#   vpc_id = "vpc-0d9b566c353787d53"
# }

# # __generated__ by Terraform
# resource "aws_launch_template" "legacy_lt_014a3e4ca5da5d14f" {
#   default_version                      = 1
#   description                          = null
#   disable_api_stop                     = false
#   disable_api_termination              = false
#   ebs_optimized                        = null
#   image_id                             = "ami-0f27749973e2399b6"
#   instance_initiated_shutdown_behavior = null
#   instance_type                        = "t3.small"
#   kernel_id                            = null
#   key_name                             = null
#   name                                 = "nomaos-asgLaunchTemplate"
#   name_prefix                          = null
#   ram_disk_id                          = null
#   tags = {
#     Name = "agrovesto-infra-deployment/nomaos-asgLaunchTemplate"
#   }
#   tags_all = {
#     Name = "agrovesto-infra-deployment/nomaos-asgLaunchTemplate"
#   }
#   update_default_version = null
#   user_data              = "IyEvYmluL2Jhc2gKc3VkbyBhcHQtZ2V0IHVwZGF0ZQpzdWRvIGFwdC1nZXQgaW5zdGFsbCAteSBuZ2lueCBweXRob24zLXBpcApwaXAzIGluc3RhbGwgLS11cGdyYWRlIHBpcApzdWRvIHN5c3RlbWN0bCBlbmFibGUgbmdpbngKc3VkbyBzeXN0ZW1jdGwgc3RhcnQgbmdpbngKZWNobyAiQVNHIDEiIHwgc3VkbyB0ZWUgL3Zhci93d3cvaHRtbC9pbmRleC5uZ2lueC1kZWJpYW4uaHRtbA=="
#   block_device_mappings {
#     device_name  = "/dev/xvda"
#     no_device    = null
#     virtual_name = null
#     ebs {
#       delete_on_termination      = null
#       encrypted                  = null
#       iops                       = 0
#       kms_key_id                 = null
#       snapshot_id                = null
#       volume_size                = 100
#       volume_type                = null
#     }
#   }
#   iam_instance_profile {
#     arn  = "arn:aws:iam::353833416626:instance-profile/nomaos-asgInstanceProfile"
#     name = null
#   }
#   network_interfaces {
#     associate_carrier_ip_address = null
#     associate_public_ip_address  = jsonencode(true)
#     delete_on_termination        = null
#     description                  = null
#     device_index                 = 0
#     interface_type               = null
#     ipv4_address_count           = 0
#     ipv4_addresses               = []
#     ipv4_prefix_count            = 0
#     ipv4_prefixes                = []
#     ipv6_address_count           = 0
#     ipv6_addresses               = []
#     ipv6_prefix_count            = 0
#     ipv6_prefixes                = []
#     network_card_index           = 0
#     network_interface_id         = null
#     primary_ipv6                 = null
#     private_ip_address           = null
#     security_groups              = ["sg-05943db64467559f0"]
#     subnet_id                    = null
#   }
#   tag_specifications {
#     resource_type = "instance"
#     tags = {
#       Name = "agrovesto-infra-deployment/nomaos-asgLaunchTemplate"
#     }
#   }
#   tag_specifications {
#     resource_type = "volume"
#     tags = {
#       Name = "agrovesto-infra-deployment/nomaos-asgLaunchTemplate"
#     }
#   }
# }

# # __generated__ by Terraform from "ec2-kernel"
# resource "aws_cloudwatch_log_group" "legacy_ec2_kernel" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "ec2-kernel"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "agxdbsubnetgroup"
# resource "aws_db_subnet_group" "legacy_agxdbsubnetgroup" {
#   description = "Subnet group for agxdb RDS instance"
#   name        = "agxdbsubnetgroup"
#   name_prefix = null
#   subnet_ids  = ["subnet-004a7f9d9cbd53ea4", "subnet-0304d72cd90dd43d9"]
#   tags        = {}
#   tags_all    = {}
# }

# # __generated__ by Terraform from "/aws/lambda/amplify-reactvitetailwind-CustomS3AutoDeleteObject-aSThv5jkev7C"
# resource "aws_cloudwatch_log_group" "legacy_aws_lambda_amplify_reactvitetailwind_customs3autodeleteobjec_2" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/lambda/amplify-reactvitetailwind-CustomS3AutoDeleteObject-aSThv5jkev7C"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "sg-0c03238e678039ac4"
# resource "aws_security_group" "legacy_sg_0c03238e678039ac4" {
#   description = "Amplify security group"
#   egress = [{
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "Allow all outbound traffic by default"
#     from_port        = 0
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "-1"
#     security_groups  = []
#     self             = false
#     to_port          = 0
#   }]
#   ingress = [{
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = ""
#     from_port        = 443
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = []
#     self             = false
#     to_port          = 443
#     }, {
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = ""
#     from_port        = 80
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = []
#     self             = false
#     to_port          = 80
#   }]
#   name                   = "agrovesto-amplify-sg"
#   name_prefix            = null
#   revoke_rules_on_delete = null
#   tags = {
#     Name = "agrovesto-amplify-sg"
#   }
#   tags_all = {
#     Name = "agrovesto-amplify-sg"
#   }
#   vpc_id = "vpc-0d9b566c353787d53"
# }

# # __generated__ by Terraform from "sg-002ee2d53f67176cb"
# resource "aws_security_group" "legacy_sg_002ee2d53f67176cb" {
#   description = "Security group attached to instances to securely connect to agxdbinstance. Modification could lead to connection loss."
#   egress = [{
#     cidr_blocks      = []
#     description      = "Rule to allow connections to agxdbinstance from any instances this security group is attached to"
#     from_port        = 1433
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = ["sg-061cfa042aa584410"]
#     self             = false
#     to_port          = 1433
#   }]
#   ingress                = []
#   name                   = "ec2-rds-1"
#   name_prefix            = null
#   revoke_rules_on_delete = null
#   tags                   = {}
#   tags_all               = {}
#   vpc_id                 = "vpc-0d9b566c353787d53"
# }

# # __generated__ by Terraform
# resource "aws_key_pair" "legacy_noma_api" {
#   key_name        = "noma-api"
#   key_name_prefix = null
#   public_key      = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD0ngyv1W/d44KJUAaFmiGOrqezjFTkiTuTdqF/PBsz/mefkXWHhzuPzV9QYm8Fe7E41NeqdBI5jIQREYT6wCic1LVMXiAJi92cbr2jRYeOP740tU8/kyj4yiLnpBaMIxi3/BRLC+8xfckcKT6ZxU07KtE5nbDBMhcTrGH5nEkowW/GOdgv0wXjn6BO/VjXwN2gHcNRBxR20ABwr+4QTj7CmOY2T+gp9uhV6Dq2rXmkowhvqRxMwFEfSx2irZkdedACm65NohbxswDDeBLZR60SHpzbUJEWz/2kqS05gVjrtj3DITF4ieuT5oa+BpCVTty73oVURe+o1h7CIPMATXyx noma-api"
#   tags            = {}
#   tags_all        = {}
#   lifecycle {
#     ignore_changes = [public_key]
#   }
# }

# # __generated__ by Terraform
# resource "aws_key_pair" "legacy_nomas_api" {
#   key_name        = "nomas-api"
#   key_name_prefix = null
#   public_key      = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC5P/Ck9k95jj57GIHv0q+rAQl0qkzAo45VemKWz0fxuLyt4+h/d0/Y5mq0jw0Sf5xquuvfeIchjICaSTUdprvRJ4dPi6734nwMwtCmq0ZU2bZBqWNq0l4j0S/PoeIynfpX+JOxUQNx9VpUMsj2pBnXFjzL8dqX3mrZ56r6FTVT0m3A9OLZo9agSeJLqomyJkl5m2Y92qEKHv4FrWAS6dvrcHoHY7eRk680I6tXZGmRbSr071edoqAe+61wdIkwInRW5K+07Y5JcHZJwX9pFb+ZqAkOXugjFKCFFfK8uSxiW1pMEE80kfV4883P3jV3xXXQwye8d1Ii5wHJffdRYEmL nomas-api"
#   tags            = {}
#   tags_all        = {}
#   lifecycle {
#     ignore_changes = [public_key]
#   }
# }

# # __generated__ by Terraform from "test-project"
# resource "aws_apprunner_connection" "legacy_test_project" {
#   connection_name = "test-project"
#   provider_type   = "GITHUB"
#   tags            = {}
#   tags_all        = {}
# }

# # __generated__ by Terraform from "subnet-004a7f9d9cbd53ea4/rtb-0fea2a4ff5a3adf0f"
# resource "aws_route_table_association" "legacy_subnet_004a7f9d9cbd53ea4" {
#   gateway_id     = null
#   route_table_id = "rtb-0fea2a4ff5a3adf0f"
#   subnet_id      = "subnet-004a7f9d9cbd53ea4"
# }

# # __generated__ by Terraform
# resource "aws_codepipeline" "legacy_nomaos" {
#   execution_mode = "QUEUED"
#   name           = "nomaos"
#   pipeline_type  = "V2"
#   role_arn       = "arn:aws:iam::353833416626:role/service-role/AWSCodePipelineServiceRole-eu-west-1-nomaos"
#   tags           = {}
#   tags_all       = {}
#   artifact_store {
#     location = "codepipeline-eu-west-1-3bf3ec101df5-4d09-9689-376482a069ed"
#     region   = null
#     type     = "S3"
#   }
#   stage {
#     name = "Source"
#     action {
#       category = "Source"
#       configuration = {
#         BranchName           = "staging"
#         ConnectionArn        = "arn:aws:codeconnections:eu-west-1:353833416626:connection/34fe4280-df27-43a0-b239-95a71c4c1d9b"
#         DetectChanges        = "true"
#         FullRepositoryId     = "Agrovesto/Agrovesto"
#         OutputArtifactFormat = "CODE_ZIP"
#       }
#       input_artifacts    = []
#       name               = "Source"
#       namespace          = "SourceVariables"
#       output_artifacts   = ["SourceArtifact"]
#       owner              = "AWS"
#       provider           = "CodeStarSourceConnection"
#       region             = "eu-west-1"
#       role_arn           = null
#       run_order          = 1
#       version            = jsonencode(1)
#     }
#     on_failure {
#       result = "RETRY"
#       retry_configuration {
#         retry_mode = "ALL_ACTIONS"
#       }
#     }
#   }
#   stage {
#     name = "Deploy"
#     action {
#       category = "Deploy"
#       configuration = {
#         InstanceTagKey   = "Name"
#         InstanceTagValue = "nomaos-api"
#         InstanceType     = "EC2"
#         PostScript       = "deploy.sh"
#         TargetDirectory  = "/home/ec2-user/nomaos"
#       }
#       input_artifacts    = ["SourceArtifact"]
#       name               = "Deploy"
#       namespace          = "DeployVariables"
#       output_artifacts   = []
#       owner              = "AWS"
#       provider           = "EC2"
#       region             = "eu-west-1"
#       role_arn           = null
#       run_order          = 1
#       version            = jsonencode(1)
#     }
#     on_failure {
#       result = "ROLLBACK"
#     }
#   }
# }

# # __generated__ by Terraform from "sg-05943db64467559f0"
# resource "aws_security_group" "legacy_sg_05943db64467559f0" {
#   description = "EC2 security group"
#   egress = [{
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "Allow all outbound traffic by default"
#     from_port        = 0
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "-1"
#     security_groups  = []
#     self             = false
#     to_port          = 0
#   }]
#   ingress = [{
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "agx-api-blue"
#     from_port        = 5003
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = []
#     self             = false
#     to_port          = 5003
#     }, {
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "http"
#     from_port        = 80
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = []
#     self             = false
#     to_port          = 80
#     }, {
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "https"
#     from_port        = 443
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = []
#     self             = false
#     to_port          = 443
#     }, {
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "mssql"
#     from_port        = 1433
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = []
#     self             = false
#     to_port          = 1433
#     }, {
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "noma-agx-blue"
#     from_port        = 5001
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = []
#     self             = false
#     to_port          = 5001
#     }, {
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "noma-api-blue"
#     from_port        = 5002
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = []
#     self             = false
#     to_port          = 5002
#     }, {
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "noma-api-green"
#     from_port        = 5000
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = []
#     self             = false
#     to_port          = 5000
#     }, {
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "sonarqube"
#     from_port        = 9000
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = []
#     self             = false
#     to_port          = 9000
#     }, {
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "ssh"
#     from_port        = 22
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = []
#     self             = false
#     to_port          = 22
#     }, {
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "vault"
#     from_port        = 8200
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = []
#     self             = false
#     to_port          = 8200
#   }]
#   name                   = "agrovesto-ec2-sg"
#   name_prefix            = null
#   revoke_rules_on_delete = null
#   tags = {
#     Name = "agrovesto-ec2-sg"
#   }
#   tags_all = {
#     Name = "agrovesto-ec2-sg"
#   }
#   vpc_id = "vpc-0d9b566c353787d53"
# }

# # __generated__ by Terraform from "vol-0a13b7e39dd6fb97d"
# resource "aws_ebs_volume" "legacy_vol_0a13b7e39dd6fb97d" {
#   availability_zone    = "eu-west-1a"
#   encrypted            = false
#   final_snapshot       = null
#   iops                 = 3000
#   kms_key_id           = null
#   multi_attach_enabled = false
#   outpost_arn          = null
#   size                 = 100
#   snapshot_id          = null
#   tags                 = {}
#   tags_all             = {}
#   throughput           = 125
#   type                 = "gp3"
# }

# # __generated__ by Terraform from "arn:aws:secretsmanager:eu-west-1:353833416626:secret:agxDBcredentials-5lcSd1"
# resource "aws_secretsmanager_secret" "legacy_agxdbcredentials" {
#   description                    = "Generated by the CDK for stack: agrovesto-infra-deployment"
#   force_overwrite_replica_secret = null
#   kms_key_id                     = null
#   name                           = "agxDBcredentials"
#   name_prefix                    = null
#   policy = jsonencode({
#     Statement = [{
#       Action = "secretsmanager:DeleteSecret"
#       Effect = "Deny"
#       Principal = {
#         AWS = "arn:aws:iam::353833416626:root"
#       }
#       Resource = "*"
#     }]
#     Version = "2012-10-17"
#   })
#   recovery_window_in_days = null
#   tags = {
#     Name = "agxdb"
#   }
#   tags_all = {
#     Name = "agxdb"
#   }
# }

# # __generated__ by Terraform from "nomaosdbsubnetgroup"
# resource "aws_db_subnet_group" "legacy_nomaosdbsubnetgroup" {
#   description = "Subnet group for nomaosdb RDS instance"
#   name        = "nomaosdbsubnetgroup"
#   name_prefix = null
#   subnet_ids  = ["subnet-0309fc43ea380ad6b", "subnet-0739cfd4c412deb3f"]
#   tags        = {}
#   tags_all    = {}
# }

# # __generated__ by Terraform from "ec2-cloud-init-output"
# resource "aws_cloudwatch_log_group" "legacy_ec2_cloud_init_output" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "ec2-cloud-init-output"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "sg-0c4d118c6776629d9"
# resource "aws_security_group" "legacy_sg_0c4d118c6776629d9" {
#   description = "Security group attached to nomaosdbinstance to allow EC2 instances with specific security groups attached to connect to the database. Modification could lead to connection loss."
#   egress      = []
#   ingress = [{
#     cidr_blocks      = []
#     description      = "Rule to allow connections from EC2 instances with sg-0d8184650fd775043 attached"
#     from_port        = 1433
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = ["sg-0d8184650fd775043"]
#     self             = false
#     to_port          = 1433
#   }]
#   name                   = "rds-ec2-2"
#   name_prefix            = null
#   revoke_rules_on_delete = null
#   tags                   = {}
#   tags_all               = {}
#   vpc_id                 = "vpc-0d9b566c353787d53"
# }

# # __generated__ by Terraform from "31f57b1f-cbde-4aa6-8c6e-18e129c80fb6"
# resource "aws_kms_key" "legacy_key_31f57b1f" {
#   bypass_policy_lockout_safety_check = null
#   custom_key_store_id                = null
#   customer_master_key_spec           = "SYMMETRIC_DEFAULT"
#   deletion_window_in_days            = null
#   description                        = "nomaos-bootstrap-dev Terraform state encryption"
#   enable_key_rotation                = true
#   is_enabled                         = true
#   key_usage                          = "ENCRYPT_DECRYPT"
#   multi_region                       = false
#   policy = jsonencode({
#     Statement = [{
#       Action = "kms:*"
#       Effect = "Allow"
#       Principal = {
#         AWS = "arn:aws:iam::353833416626:root"
#       }
#       Resource = "*"
#     }]
#     Version = "2012-10-17"
#   })
#   rotation_period_in_days = 365
#   tags = {
#     Component = "bootstrap"
#     ManagedBy = "Terraform"
#     Project   = "nomaos"
#   }
#   tags_all = {
#     Component   = "bootstrap"
#     Environment = "dev"
#     ManagedBy   = "Terraform"
#     Project     = "nomaos"
#   }
#   xks_key_id = null
# }

# # __generated__ by Terraform from "arn:aws:resource-explorer-2:eu-west-1:353833416626:index/5a315ef4-dfcb-47cf-bea0-815907217a6c"
# resource "aws_resourceexplorer2_index" "legacy_index" {
#   tags = null
#   type = "LOCAL"
# }

# # __generated__ by Terraform from "arn:aws:resource-explorer-2:eu-west-1:353833416626:view/eu-west-1/b9917b43-4a1a-4504-ac28-274a4e9c3b1e"
# resource "aws_resourceexplorer2_view" "legacy_view" {
#   default_view = true
#   name         = "eu-west-1"
#   scope        = "arn:aws:iam::353833416626:root"
#   tags         = null
#   included_property {
#     name = "tags"
#   }
# }

# # __generated__ by Terraform from "/aws/lambda/agrovesto-infra-deploymen-CustomVpcRestrictDefault-KU3EPogQo5Br"
# resource "aws_cloudwatch_log_group" "legacy_aws_lambda_agrovesto_infra_deploymen_customvpcrestrictdefaul" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/lambda/agrovesto-infra-deploymen-CustomVpcRestrictDefault-KU3EPogQo5Br"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "eipalloc-0b7f04c0906f47a4e"
# resource "aws_eip" "legacy_eipalloc_0b7f04c0906f47a4e" {
#   address                   = null
#   associate_with_private_ip = null
#   customer_owned_ipv4_pool  = null
#   domain                    = "vpc"
#   instance                  = "i-00af32231113d64f9"
#   ipam_pool_id              = null
#   network_border_group      = "eu-west-1"
#   network_interface         = "eni-0bcfbc9a627cf4e67"
#   public_ipv4_pool          = "amazon"
#   tags                      = {}
#   tags_all                  = {}
# }

# # __generated__ by Terraform from "sg-0e299611b6b1a93fd"
# resource "aws_security_group" "legacy_sg_0e299611b6b1a93fd" {
#   description = "MSsql security group"
#   egress = [{
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "Allow all outbound traffic by default"
#     from_port        = 0
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "-1"
#     security_groups  = []
#     self             = false
#     to_port          = 0
#   }]
#   ingress = [{
#     cidr_blocks      = []
#     description      = ""
#     from_port        = 1433
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = ["sg-05943db64467559f0"]
#     self             = false
#     to_port          = 1433
#     }, {
#     cidr_blocks      = []
#     description      = "from agrovestoinfradeploymentagxdbRotationSingleUserSecurityGroup9D54F98A:{IndirectPort}"
#     from_port        = 1433
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = ["sg-039c167fa924e64ee"]
#     self             = false
#     to_port          = 1433
#     }, {
#     cidr_blocks      = []
#     description      = "from agrovestoinfradeploymentnomaosdbRotationSingleUserSecurityGroupE5889A34:{IndirectPort}"
#     from_port        = 1433
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = ["sg-003093b317e5032f7"]
#     self             = false
#     to_port          = 1433
#   }]
#   name                   = "agrovesto-db-sg"
#   name_prefix            = null
#   revoke_rules_on_delete = null
#   tags = {
#     Name = "agrovesto-db-sg"
#   }
#   tags_all = {
#     Name = "agrovesto-db-sg"
#   }
#   vpc_id = "vpc-0d9b566c353787d53"
# }

# # __generated__ by Terraform from "sg-061cfa042aa584410"
# resource "aws_security_group" "legacy_sg_061cfa042aa584410" {
#   description = "Security group attached to agxdbinstance to allow EC2 instances with specific security groups attached to connect to the database. Modification could lead to connection loss."
#   egress      = []
#   ingress = [{
#     cidr_blocks      = []
#     description      = "Rule to allow connections from EC2 instances with sg-002ee2d53f67176cb attached"
#     from_port        = 1433
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "tcp"
#     security_groups  = ["sg-002ee2d53f67176cb"]
#     self             = false
#     to_port          = 1433
#   }]
#   name                   = "rds-ec2-1"
#   name_prefix            = null
#   revoke_rules_on_delete = null
#   tags                   = {}
#   tags_all               = {}
#   vpc_id                 = "vpc-0d9b566c353787d53"
# }

# # __generated__ by Terraform
# resource "aws_subnet" "legacy_subnet_0304d72cd90dd43d9" {
#   assign_ipv6_address_on_creation                = false
#   availability_zone                              = "eu-west-1a"
#   availability_zone_id                           = "euw1-az2"
#   cidr_block                                     = "172.96.2.0/24"
#   customer_owned_ipv4_pool                       = null
#   enable_dns64                                   = false
#   enable_lni_at_device_index                     = 0
#   enable_resource_name_dns_a_record_on_launch    = false
#   enable_resource_name_dns_aaaa_record_on_launch = false
#   ipv6_cidr_block                                = null
#   ipv6_native                                    = false
#   map_customer_owned_ip_on_launch                = false
#   map_public_ip_on_launch                        = false
#   outpost_arn                                    = null
#   private_dns_hostname_type_on_launch            = "ip-name"
#   tags = {
#     Name                  = "agrovesto-infra-deployment/agrovesto-vpc/privateSubnet1"
#     "aws-cdk:subnet-name" = "private"
#     "aws-cdk:subnet-type" = "Private"
#   }
#   tags_all = {
#     Name                  = "agrovesto-infra-deployment/agrovesto-vpc/privateSubnet1"
#     "aws-cdk:subnet-name" = "private"
#     "aws-cdk:subnet-type" = "Private"
#   }
#   vpc_id = "vpc-0d9b566c353787d53"
# }

# # __generated__ by Terraform from "RDSOSMetrics"
# resource "aws_cloudwatch_log_group" "legacy_rdsosmetrics" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "RDSOSMetrics"
#   name_prefix       = null
#   retention_in_days = 30
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "rtb-04a4e32b4443f50d5"
# resource "aws_route_table" "legacy_rtb_04a4e32b4443f50d5" {
#   propagating_vgws = []
#   route            = []
#   tags = {
#     Name = "agrovesto-infra-deployment/agrovesto-vpc/privateSubnet1"
#   }
#   tags_all = {
#     Name = "agrovesto-infra-deployment/agrovesto-vpc/privateSubnet1"
#   }
#   vpc_id = "vpc-0d9b566c353787d53"
# }

# # __generated__ by Terraform from "CDKToolkit"
# resource "aws_cloudformation_stack" "legacy_cdktoolkit" {
#   capabilities       = ["CAPABILITY_AUTO_EXPAND", "CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]
#   disable_rollback   = false
#   iam_role_arn       = null
#   name               = "CDKToolkit"
#   notification_arns  = null
#   on_failure         = null
#   parameters         = {}
#   policy_body        = null
#   policy_url         = null
#   tags               = {}
#   tags_all           = {}
#   template_body      = "Description: This stack includes resources needed to deploy AWS CDK apps into this environment\nParameters:\n  TrustedAccounts:\n    Description: List of AWS accounts that are trusted to publish assets and deploy stacks to this environment\n    Default: \"\"\n    Type: CommaDelimitedList\n  TrustedAccountsForLookup:\n    Description: List of AWS accounts that are trusted to look up values in this environment\n    Default: \"\"\n    Type: CommaDelimitedList\n  CloudFormationExecutionPolicies:\n    Description: List of the ManagedPolicy ARN(s) to attach to the CloudFormation deployment role\n    Default: \"\"\n    Type: CommaDelimitedList\n  FileAssetsBucketName:\n    Description: The name of the S3 bucket used for file assets\n    Default: \"\"\n    Type: String\n  FileAssetsBucketKmsKeyId:\n    Description: Empty to create a new key (default), 'AWS_MANAGED_KEY' to use a managed S3 key, or the ID/ARN of an existing key.\n    Default: \"\"\n    Type: String\n  ContainerAssetsRepositoryName:\n    Description: A user-provided custom name to use for the container assets ECR repository\n    Default: \"\"\n    Type: String\n  Qualifier:\n    Description: An identifier to distinguish multiple bootstrap stacks in the same environment\n    Default: hnb659fds\n    Type: String\n    AllowedPattern: \"[A-Za-z0-9_-]{1,10}\"\n    ConstraintDescription: Qualifier must be an alphanumeric identifier of at most 10 characters\n  PublicAccessBlockConfiguration:\n    Description: Whether or not to enable S3 Staging Bucket Public Access Block Configuration\n    Default: \"true\"\n    Type: String\n    AllowedValues:\n      - \"true\"\n      - \"false\"\n  InputPermissionsBoundary:\n    Description: Whether or not to use either the CDK supplied or custom permissions boundary\n    Default: \"\"\n    Type: String\n  UseExamplePermissionsBoundary:\n    Default: \"false\"\n    AllowedValues:\n      - \"true\"\n      - \"false\"\n    Type: String\n  BootstrapVariant:\n    Type: String\n    Default: \"AWS CDK: Default Resources\"\n    Description: Describe the provenance of the resources in this bootstrap stack. Change this when you customize the template. To prevent accidents, the CDK CLI will not overwrite bootstrap stacks with a different variant.\n  DenyExternalId:\n    Type: String\n    Default: \"true\"\n    AllowedValues:\n      - \"true\"\n      - \"false\"\n    Description: Whether to deny AssumeRole calls with an ExternalId. This prevents calls that are intended to be deputized from accidentally assuming CDK Roles.\nConditions:\n  HasTrustedAccounts:\n    Fn::Not:\n      - Fn::Equals:\n          - \"\"\n          - Fn::Join:\n              - \"\"\n              - Ref: TrustedAccounts\n  HasTrustedAccountsForLookup:\n    Fn::Not:\n      - Fn::Equals:\n          - \"\"\n          - Fn::Join:\n              - \"\"\n              - Ref: TrustedAccountsForLookup\n  HasCloudFormationExecutionPolicies:\n    Fn::Not:\n      - Fn::Equals:\n          - \"\"\n          - Fn::Join:\n              - \"\"\n              - Ref: CloudFormationExecutionPolicies\n  HasCustomFileAssetsBucketName:\n    Fn::Not:\n      - Fn::Equals:\n          - \"\"\n          - Ref: FileAssetsBucketName\n  CreateNewKey:\n    Fn::Equals:\n      - \"\"\n      - Ref: FileAssetsBucketKmsKeyId\n  UseAwsManagedKey:\n    Fn::Equals:\n      - AWS_MANAGED_KEY\n      - Ref: FileAssetsBucketKmsKeyId\n  ShouldCreatePermissionsBoundary:\n    Fn::Equals:\n      - \"true\"\n      - Ref: UseExamplePermissionsBoundary\n  PermissionsBoundarySet:\n    Fn::Not:\n      - Fn::Equals:\n          - \"\"\n          - Ref: InputPermissionsBoundary\n  HasCustomContainerAssetsRepositoryName:\n    Fn::Not:\n      - Fn::Equals:\n          - \"\"\n          - Ref: ContainerAssetsRepositoryName\n  UsePublicAccessBlockConfiguration:\n    Fn::Equals:\n      - \"true\"\n      - Ref: PublicAccessBlockConfiguration\n  ShouldDenyExternalId:\n    Fn::Equals:\n      - \"true\"\n      - Ref: DenyExternalId\nResources:\n  FileAssetsBucketEncryptionKey:\n    Type: AWS::KMS::Key\n    Properties:\n      KeyPolicy:\n        Statement:\n          - Action:\n              - kms:Create*\n              - kms:Describe*\n              - kms:Enable*\n              - kms:List*\n              - kms:Put*\n              - kms:Update*\n              - kms:Revoke*\n              - kms:Disable*\n              - kms:Get*\n              - kms:Delete*\n              - kms:ScheduleKeyDeletion\n              - kms:CancelKeyDeletion\n              - kms:GenerateDataKey\n              - kms:TagResource\n              - kms:UntagResource\n            Effect: Allow\n            Principal:\n              AWS:\n                Ref: AWS::AccountId\n            Resource: \"*\"\n          - Action:\n              - kms:Decrypt\n              - kms:DescribeKey\n              - kms:Encrypt\n              - kms:ReEncrypt*\n              - kms:GenerateDataKey*\n            Effect: Allow\n            Principal:\n              AWS: \"*\"\n            Resource: \"*\"\n            Condition:\n              StringEquals:\n                kms:CallerAccount:\n                  Ref: AWS::AccountId\n                kms:ViaService:\n                  - Fn::Sub: s3.$${AWS::Region}.amazonaws.com\n          - Action:\n              - kms:Decrypt\n              - kms:DescribeKey\n              - kms:Encrypt\n              - kms:ReEncrypt*\n              - kms:GenerateDataKey*\n            Effect: Allow\n            Principal:\n              AWS:\n                Fn::Sub: $${FilePublishingRole.Arn}\n            Resource: \"*\"\n    Condition: CreateNewKey\n    UpdateReplacePolicy: Delete\n    DeletionPolicy: Delete\n  FileAssetsBucketEncryptionKeyAlias:\n    Condition: CreateNewKey\n    Type: AWS::KMS::Alias\n    Properties:\n      AliasName:\n        Fn::Sub: alias/cdk-$${Qualifier}-assets-key\n      TargetKeyId:\n        Ref: FileAssetsBucketEncryptionKey\n  StagingBucket:\n    Type: AWS::S3::Bucket\n    Properties:\n      BucketName:\n        Fn::If:\n          - HasCustomFileAssetsBucketName\n          - Fn::Sub: $${FileAssetsBucketName}\n          - Fn::Sub: cdk-$${Qualifier}-assets-$${AWS::AccountId}-$${AWS::Region}\n      AccessControl: Private\n      BucketEncryption:\n        ServerSideEncryptionConfiguration:\n          - ServerSideEncryptionByDefault:\n              SSEAlgorithm: aws:kms\n              KMSMasterKeyID:\n                Fn::If:\n                  - CreateNewKey\n                  - Fn::Sub: $${FileAssetsBucketEncryptionKey.Arn}\n                  - Fn::If:\n                      - UseAwsManagedKey\n                      - Ref: AWS::NoValue\n                      - Fn::Sub: $${FileAssetsBucketKmsKeyId}\n      PublicAccessBlockConfiguration:\n        Fn::If:\n          - UsePublicAccessBlockConfiguration\n          - BlockPublicAcls: true\n            BlockPublicPolicy: true\n            IgnorePublicAcls: true\n            RestrictPublicBuckets: true\n          - Ref: AWS::NoValue\n      VersioningConfiguration:\n        Status: Enabled\n      LifecycleConfiguration:\n        Rules:\n          - Id: CleanupOldVersions\n            Status: Enabled\n            NoncurrentVersionExpiration:\n              NoncurrentDays: 30\n          - Id: AbortIncompleteMultipartUploads\n            Status: Enabled\n            AbortIncompleteMultipartUpload:\n              DaysAfterInitiation: 1\n    UpdateReplacePolicy: Retain\n    DeletionPolicy: Retain\n  StagingBucketPolicy:\n    Type: AWS::S3::BucketPolicy\n    Properties:\n      Bucket:\n        Ref: StagingBucket\n      PolicyDocument:\n        Id: AccessControl\n        Version: \"2012-10-17\"\n        Statement:\n          - Sid: AllowSSLRequestsOnly\n            Action: s3:*\n            Effect: Deny\n            Resource:\n              - Fn::Sub: $${StagingBucket.Arn}\n              - Fn::Sub: $${StagingBucket.Arn}/*\n            Condition:\n              Bool:\n                aws:SecureTransport: \"false\"\n            Principal: \"*\"\n  ContainerAssetsRepository:\n    Type: AWS::ECR::Repository\n    Properties:\n      ImageTagMutability: IMMUTABLE\n      LifecyclePolicy:\n        LifecyclePolicyText: |\n          {\n            \"rules\": [\n              {\n                \"rulePriority\": 1,\n                \"description\": \"Untagged images should not exist, but expire any older than one year\",\n                \"selection\": {\n                  \"tagStatus\": \"untagged\",\n                  \"countType\": \"sinceImagePushed\",\n                  \"countUnit\": \"days\",\n                  \"countNumber\": 365\n                },\n                \"action\": { \"type\": \"expire\" }\n              }\n            ]\n          }\n      RepositoryName:\n        Fn::If:\n          - HasCustomContainerAssetsRepositoryName\n          - Fn::Sub: $${ContainerAssetsRepositoryName}\n          - Fn::Sub: cdk-$${Qualifier}-container-assets-$${AWS::AccountId}-$${AWS::Region}\n      RepositoryPolicyText:\n        Version: \"2012-10-17\"\n        Statement:\n          - Sid: LambdaECRImageRetrievalPolicy\n            Effect: Allow\n            Principal:\n              Service: lambda.amazonaws.com\n            Action:\n              - ecr:BatchGetImage\n              - ecr:GetDownloadUrlForLayer\n            Condition:\n              StringLike:\n                aws:sourceArn:\n                  Fn::Sub: arn:$${AWS::Partition}:lambda:$${AWS::Region}:$${AWS::AccountId}:function:*\n          - Sid: EmrServerlessImageRetrievalPolicy\n            Effect: Allow\n            Principal:\n              Service: emr-serverless.amazonaws.com\n            Action:\n              - ecr:BatchGetImage\n              - ecr:GetDownloadUrlForLayer\n              - ecr:DescribeImages\n            Condition:\n              StringLike:\n                aws:sourceArn:\n                  Fn::Sub: arn:$${AWS::Partition}:emr-serverless:$${AWS::Region}:$${AWS::AccountId}:/applications/*\n  FilePublishingRole:\n    Type: AWS::IAM::Role\n    Properties:\n      AssumeRolePolicyDocument:\n        Statement:\n          - Action: sts:AssumeRole\n            Effect: Allow\n            Principal:\n              AWS:\n                Ref: AWS::AccountId\n            Condition:\n              Fn::If:\n                - ShouldDenyExternalId\n                - \"Null\":\n                    sts:ExternalId: \"true\"\n                - Ref: AWS::NoValue\n          - Action: sts:TagSession\n            Effect: Allow\n            Principal:\n              AWS:\n                Ref: AWS::AccountId\n          - Fn::If:\n              - HasTrustedAccounts\n              - Action:\n                  - sts:AssumeRole\n                Effect: Allow\n                Principal:\n                  AWS:\n                    Ref: TrustedAccounts\n                Condition:\n                  Fn::If:\n                    - ShouldDenyExternalId\n                    - \"Null\":\n                        sts:ExternalId: \"true\"\n                    - Ref: AWS::NoValue\n              - Ref: AWS::NoValue\n          - Fn::If:\n              - HasTrustedAccounts\n              - Action:\n                  - sts:TagSession\n                Effect: Allow\n                Principal:\n                  AWS:\n                    Ref: TrustedAccounts\n              - Ref: AWS::NoValue\n      RoleName:\n        Fn::Sub: cdk-$${Qualifier}-file-publishing-role-$${AWS::AccountId}-$${AWS::Region}\n      Tags:\n        - Key: aws-cdk:bootstrap-role\n          Value: file-publishing\n  ImagePublishingRole:\n    Type: AWS::IAM::Role\n    Properties:\n      AssumeRolePolicyDocument:\n        Statement:\n          - Action: sts:AssumeRole\n            Effect: Allow\n            Principal:\n              AWS:\n                Ref: AWS::AccountId\n            Condition:\n              Fn::If:\n                - ShouldDenyExternalId\n                - \"Null\":\n                    sts:ExternalId: \"true\"\n                - Ref: AWS::NoValue\n          - Action: sts:TagSession\n            Effect: Allow\n            Principal:\n              AWS:\n                Ref: AWS::AccountId\n          - Fn::If:\n              - HasTrustedAccounts\n              - Action:\n                  - sts:AssumeRole\n                Effect: Allow\n                Principal:\n                  AWS:\n                    Ref: TrustedAccounts\n                Condition:\n                  Fn::If:\n                    - ShouldDenyExternalId\n                    - \"Null\":\n                        sts:ExternalId: \"true\"\n                    - Ref: AWS::NoValue\n              - Ref: AWS::NoValue\n          - Fn::If:\n              - HasTrustedAccounts\n              - Action:\n                  - sts:TagSession\n                Effect: Allow\n                Principal:\n                  AWS:\n                    Ref: TrustedAccounts\n              - Ref: AWS::NoValue\n      RoleName:\n        Fn::Sub: cdk-$${Qualifier}-image-publishing-role-$${AWS::AccountId}-$${AWS::Region}\n      Tags:\n        - Key: aws-cdk:bootstrap-role\n          Value: image-publishing\n  LookupRole:\n    Type: AWS::IAM::Role\n    Properties:\n      AssumeRolePolicyDocument:\n        Statement:\n          - Action: sts:AssumeRole\n            Effect: Allow\n            Principal:\n              AWS:\n                Ref: AWS::AccountId\n            Condition:\n              Fn::If:\n                - ShouldDenyExternalId\n                - \"Null\":\n                    sts:ExternalId: \"true\"\n                - Ref: AWS::NoValue\n          - Action: sts:TagSession\n            Effect: Allow\n            Principal:\n              AWS:\n                Ref: AWS::AccountId\n          - Fn::If:\n              - HasTrustedAccountsForLookup\n              - Action:\n                  - sts:AssumeRole\n                Effect: Allow\n                Principal:\n                  AWS:\n                    Ref: TrustedAccountsForLookup\n                Condition:\n                  Fn::If:\n                    - ShouldDenyExternalId\n                    - \"Null\":\n                        sts:ExternalId: \"true\"\n                    - Ref: AWS::NoValue\n              - Ref: AWS::NoValue\n          - Fn::If:\n              - HasTrustedAccountsForLookup\n              - Action:\n                  - sts:TagSession\n                Effect: Allow\n                Principal:\n                  AWS:\n                    Ref: TrustedAccountsForLookup\n              - Ref: AWS::NoValue\n          - Fn::If:\n              - HasTrustedAccounts\n              - Action:\n                  - sts:AssumeRole\n                Effect: Allow\n                Principal:\n                  AWS:\n                    Ref: TrustedAccounts\n                Condition:\n                  Fn::If:\n                    - ShouldDenyExternalId\n                    - \"Null\":\n                        sts:ExternalId: \"true\"\n                    - Ref: AWS::NoValue\n              - Ref: AWS::NoValue\n          - Fn::If:\n              - HasTrustedAccounts\n              - Action:\n                  - sts:TagSession\n                Effect: Allow\n                Principal:\n                  AWS:\n                    Ref: TrustedAccounts\n              - Ref: AWS::NoValue\n      RoleName:\n        Fn::Sub: cdk-$${Qualifier}-lookup-role-$${AWS::AccountId}-$${AWS::Region}\n      ManagedPolicyArns:\n        - Fn::Sub: arn:$${AWS::Partition}:iam::aws:policy/ReadOnlyAccess\n      Policies:\n        - PolicyDocument:\n            Statement:\n              - Sid: DontReadSecrets\n                Effect: Deny\n                Action:\n                  - kms:Decrypt\n                Resource: \"*\"\n            Version: \"2012-10-17\"\n          PolicyName: LookupRolePolicy\n      Tags:\n        - Key: aws-cdk:bootstrap-role\n          Value: lookup\n  FilePublishingRoleDefaultPolicy:\n    Type: AWS::IAM::Policy\n    Properties:\n      PolicyDocument:\n        Statement:\n          - Action:\n              - s3:GetObject*\n              - s3:GetBucket*\n              - s3:GetEncryptionConfiguration\n              - s3:List*\n              - s3:DeleteObject*\n              - s3:PutObject*\n              - s3:Abort*\n            Resource:\n              - Fn::Sub: $${StagingBucket.Arn}\n              - Fn::Sub: $${StagingBucket.Arn}/*\n            Condition:\n              StringEquals:\n                aws:ResourceAccount:\n                  - Fn::Sub: $${AWS::AccountId}\n            Effect: Allow\n          - Action:\n              - kms:Decrypt\n              - kms:DescribeKey\n              - kms:Encrypt\n              - kms:ReEncrypt*\n              - kms:GenerateDataKey*\n            Effect: Allow\n            Resource:\n              Fn::If:\n                - CreateNewKey\n                - Fn::Sub: $${FileAssetsBucketEncryptionKey.Arn}\n                - Fn::Sub: arn:$${AWS::Partition}:kms:$${AWS::Region}:$${AWS::AccountId}:key/$${FileAssetsBucketKmsKeyId}\n        Version: \"2012-10-17\"\n      Roles:\n        - Ref: FilePublishingRole\n      PolicyName:\n        Fn::Sub: cdk-$${Qualifier}-file-publishing-role-default-policy-$${AWS::AccountId}-$${AWS::Region}\n  ImagePublishingRoleDefaultPolicy:\n    Type: AWS::IAM::Policy\n    Properties:\n      PolicyDocument:\n        Statement:\n          - Action:\n              - ecr:PutImage\n              - ecr:InitiateLayerUpload\n              - ecr:UploadLayerPart\n              - ecr:CompleteLayerUpload\n              - ecr:BatchCheckLayerAvailability\n              - ecr:DescribeRepositories\n              - ecr:DescribeImages\n              - ecr:BatchGetImage\n              - ecr:GetDownloadUrlForLayer\n            Resource:\n              Fn::Sub: $${ContainerAssetsRepository.Arn}\n            Effect: Allow\n          - Action:\n              - ecr:GetAuthorizationToken\n            Resource: \"*\"\n            Effect: Allow\n        Version: \"2012-10-17\"\n      Roles:\n        - Ref: ImagePublishingRole\n      PolicyName:\n        Fn::Sub: cdk-$${Qualifier}-image-publishing-role-default-policy-$${AWS::AccountId}-$${AWS::Region}\n  DeploymentActionRole:\n    Type: AWS::IAM::Role\n    Properties:\n      AssumeRolePolicyDocument:\n        Statement:\n          - Action: sts:AssumeRole\n            Effect: Allow\n            Principal:\n              AWS:\n                Ref: AWS::AccountId\n            Condition:\n              Fn::If:\n                - ShouldDenyExternalId\n                - \"Null\":\n                    sts:ExternalId: \"true\"\n                - Ref: AWS::NoValue\n          - Action: sts:TagSession\n            Effect: Allow\n            Principal:\n              AWS:\n                Ref: AWS::AccountId\n          - Fn::If:\n              - HasTrustedAccounts\n              - Action:\n                  - sts:AssumeRole\n                Effect: Allow\n                Principal:\n                  AWS:\n                    Ref: TrustedAccounts\n                Condition:\n                  Fn::If:\n                    - ShouldDenyExternalId\n                    - \"Null\":\n                        sts:ExternalId: \"true\"\n                    - Ref: AWS::NoValue\n              - Ref: AWS::NoValue\n          - Fn::If:\n              - HasTrustedAccounts\n              - Action:\n                  - sts:TagSession\n                Effect: Allow\n                Principal:\n                  AWS:\n                    Ref: TrustedAccounts\n              - Ref: AWS::NoValue\n      Policies:\n        - PolicyDocument:\n            Statement:\n              - Sid: CloudFormationPermissions\n                Effect: Allow\n                Action:\n                  - cloudformation:CreateChangeSet\n                  - cloudformation:DeleteChangeSet\n                  - cloudformation:DescribeChangeSet\n                  - cloudformation:DescribeStacks\n                  - cloudformation:ExecuteChangeSet\n                  - cloudformation:CreateStack\n                  - cloudformation:UpdateStack\n                  - cloudformation:RollbackStack\n                  - cloudformation:ContinueUpdateRollback\n                Resource: \"*\"\n              - Sid: PipelineCrossAccountArtifactsBucket\n                Effect: Allow\n                Action:\n                  - s3:GetObject*\n                  - s3:GetBucket*\n                  - s3:List*\n                  - s3:Abort*\n                  - s3:DeleteObject*\n                  - s3:PutObject*\n                Resource: \"*\"\n                Condition:\n                  StringNotEquals:\n                    s3:ResourceAccount:\n                      Ref: AWS::AccountId\n              - Sid: PipelineCrossAccountArtifactsKey\n                Effect: Allow\n                Action:\n                  - kms:Decrypt\n                  - kms:DescribeKey\n                  - kms:Encrypt\n                  - kms:ReEncrypt*\n                  - kms:GenerateDataKey*\n                Resource: \"*\"\n                Condition:\n                  StringEquals:\n                    kms:ViaService:\n                      Fn::Sub: s3.$${AWS::Region}.amazonaws.com\n              - Action: iam:PassRole\n                Resource:\n                  Fn::Sub: $${CloudFormationExecutionRole.Arn}\n                Effect: Allow\n              - Sid: CliPermissions\n                Action:\n                  - cloudformation:DescribeStackEvents\n                  - cloudformation:GetTemplate\n                  - cloudformation:DeleteStack\n                  - cloudformation:UpdateTerminationProtection\n                  - sts:GetCallerIdentity\n                  - cloudformation:GetTemplateSummary\n                Resource: \"*\"\n                Effect: Allow\n              - Sid: CliStagingBucket\n                Effect: Allow\n                Action:\n                  - s3:GetObject*\n                  - s3:GetBucket*\n                  - s3:List*\n                Resource:\n                  - Fn::Sub: $${StagingBucket.Arn}\n                  - Fn::Sub: $${StagingBucket.Arn}/*\n              - Sid: ReadVersion\n                Effect: Allow\n                Action:\n                  - ssm:GetParameter\n                  - ssm:GetParameters\n                Resource:\n                  - Fn::Sub: arn:$${AWS::Partition}:ssm:$${AWS::Region}:$${AWS::AccountId}:parameter$${CdkBootstrapVersion}\n              - Sid: Refactor\n                Effect: Allow\n                Action:\n                  - cloudformation:CreateStackRefactor\n                  - cloudformation:DescribeStackRefactor\n                  - cloudformation:ExecuteStackRefactor\n                  - cloudformation:ListStackRefactorActions\n                  - cloudformation:ListStackRefactors\n                  - cloudformation:ListStacks\n                Resource: \"*\"\n            Version: \"2012-10-17\"\n          PolicyName: default\n      RoleName:\n        Fn::Sub: cdk-$${Qualifier}-deploy-role-$${AWS::AccountId}-$${AWS::Region}\n      Tags:\n        - Key: aws-cdk:bootstrap-role\n          Value: deploy\n  CloudFormationExecutionRole:\n    Type: AWS::IAM::Role\n    Properties:\n      AssumeRolePolicyDocument:\n        Statement:\n          - Action: sts:AssumeRole\n            Effect: Allow\n            Principal:\n              Service: cloudformation.amazonaws.com\n        Version: \"2012-10-17\"\n      ManagedPolicyArns:\n        Fn::If:\n          - HasCloudFormationExecutionPolicies\n          - Ref: CloudFormationExecutionPolicies\n          - Fn::If:\n              - HasTrustedAccounts\n              - Ref: AWS::NoValue\n              - - Fn::Sub: arn:$${AWS::Partition}:iam::aws:policy/AdministratorAccess\n      RoleName:\n        Fn::Sub: cdk-$${Qualifier}-cfn-exec-role-$${AWS::AccountId}-$${AWS::Region}\n      PermissionsBoundary:\n        Fn::If:\n          - PermissionsBoundarySet\n          - Fn::Sub: arn:$${AWS::Partition}:iam::$${AWS::AccountId}:policy/$${InputPermissionsBoundary}\n          - Ref: AWS::NoValue\n  CdkBoostrapPermissionsBoundaryPolicy:\n    Condition: ShouldCreatePermissionsBoundary\n    Type: AWS::IAM::ManagedPolicy\n    Properties:\n      PolicyDocument:\n        Statement:\n          - Sid: ExplicitAllowAll\n            Action:\n              - \"*\"\n            Effect: Allow\n            Resource: \"*\"\n          - Sid: DenyAccessIfRequiredPermBoundaryIsNotBeingApplied\n            Action:\n              - iam:CreateUser\n              - iam:CreateRole\n              - iam:PutRolePermissionsBoundary\n              - iam:PutUserPermissionsBoundary\n            Condition:\n              StringNotEquals:\n                iam:PermissionsBoundary:\n                  Fn::Sub: arn:$${AWS::Partition}:iam::$${AWS::AccountId}:policy/cdk-$${Qualifier}-permissions-boundary-$${AWS::AccountId}-$${AWS::Region}\n            Effect: Deny\n            Resource: \"*\"\n          - Sid: DenyPermBoundaryIAMPolicyAlteration\n            Action:\n              - iam:CreatePolicyVersion\n              - iam:DeletePolicy\n              - iam:DeletePolicyVersion\n              - iam:SetDefaultPolicyVersion\n            Effect: Deny\n            Resource:\n              Fn::Sub: arn:$${AWS::Partition}:iam::$${AWS::AccountId}:policy/cdk-$${Qualifier}-permissions-boundary-$${AWS::AccountId}-$${AWS::Region}\n          - Sid: DenyRemovalOfPermBoundaryFromAnyUserOrRole\n            Action:\n              - iam:DeleteUserPermissionsBoundary\n              - iam:DeleteRolePermissionsBoundary\n            Effect: Deny\n            Resource: \"*\"\n        Version: \"2012-10-17\"\n      Description: Bootstrap Permission Boundary\n      ManagedPolicyName:\n        Fn::Sub: cdk-$${Qualifier}-permissions-boundary-$${AWS::AccountId}-$${AWS::Region}\n      Path: /\n  CdkBootstrapVersion:\n    Type: AWS::SSM::Parameter\n    Properties:\n      Type: String\n      Name:\n        Fn::Sub: /cdk-bootstrap/$${Qualifier}/version\n      Value: \"29\"\nOutputs:\n  BucketName:\n    Description: The name of the S3 bucket owned by the CDK toolkit stack\n    Value:\n      Fn::Sub: $${StagingBucket}\n  BucketDomainName:\n    Description: The domain name of the S3 bucket owned by the CDK toolkit stack\n    Value:\n      Fn::Sub: $${StagingBucket.RegionalDomainName}\n  FileAssetKeyArn:\n    Description: The ARN of the KMS key used to encrypt the asset bucket (deprecated)\n    Value:\n      Fn::If:\n        - CreateNewKey\n        - Fn::Sub: $${FileAssetsBucketEncryptionKey.Arn}\n        - Fn::Sub: $${FileAssetsBucketKmsKeyId}\n    Export:\n      Name:\n        Fn::Sub: CdkBootstrap-$${Qualifier}-FileAssetKeyArn\n  ImageRepositoryName:\n    Description: The name of the ECR repository which hosts docker image assets\n    Value:\n      Fn::Sub: $${ContainerAssetsRepository}\n  BootstrapVersion:\n    Description: The version of the bootstrap resources that are currently mastered in this stack\n    Value: \"29\"\n"
#   template_url       = null
#   timeout_in_minutes = 0
# }

# # __generated__ by Terraform from "d1grwi75us24mx"
# resource "aws_amplify_app" "legacy_d1grwi75us24mx" {
#   access_token                  = null # sensitive
#   auto_branch_creation_patterns = []
#   basic_auth_credentials        = null # sensitive
#   build_spec                    = "version: 1\nfrontend:\n  phases:\n    preBuild:\n      commands:\n        - npm ci --cache .npm --prefer-offline --legacy-peer-deps\n    build:\n      commands:\n        - npm run build --legacy-peer-deps\n  artifacts:\n    baseDirectory: dist\n    files:\n      - '**/*'\n  cache:\n    paths:\n      - .npm/**/*\n"
#   compute_role_arn              = null
#   custom_headers                = null
#   description                   = null
#   enable_auto_branch_creation   = false
#   enable_basic_auth             = false
#   enable_branch_auto_build      = false
#   enable_branch_auto_deletion   = false
#   environment_variables         = {}
#   iam_service_role_arn          = null
#   name                          = "Monitoring-and-Evaluation-as-service"
#   oauth_token                   = null # sensitive
#   platform                      = "WEB"
#   repository                    = "https://github.com/Agrovesto/Monitoring-and-Evaluation-as-service"
#   tags                          = {}
#   tags_all                      = {}
#   cache_config {
#     type = "AMPLIFY_MANAGED_NO_COOKIES"
#   }
#   custom_rule {
#     condition = null
#     source    = "/<*>"
#     status    = "404-200"
#     target    = "/index.html"
#   }
# }

# # __generated__ by Terraform from "/aws/apprunner/test/fb582698e8b8432e897d90caf920f6ec/service"
# resource "aws_cloudwatch_log_group" "legacy_aws_apprunner_test_fb582698e8b8432e897d90caf920f6ec_service" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/apprunner/test/fb582698e8b8432e897d90caf920f6ec/service"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "arn:aws:secretsmanager:eu-west-1:353833416626:secret:nomaosDBcredentials-u4Bs7W"
# resource "aws_secretsmanager_secret" "legacy_nomaosdbcredentials" {
#   description                    = "Generated by the CDK for stack: agrovesto-infra-deployment"
#   force_overwrite_replica_secret = null
#   kms_key_id                     = null
#   name                           = "nomaosDBcredentials"
#   name_prefix                    = null
#   policy = jsonencode({
#     Statement = [{
#       Action = "secretsmanager:DeleteSecret"
#       Effect = "Deny"
#       Principal = {
#         AWS = "arn:aws:iam::353833416626:root"
#       }
#       Resource = "*"
#     }]
#     Version = "2012-10-17"
#   })
#   recovery_window_in_days = null
#   tags = {
#     Name = "nomaosdb"
#   }
#   tags_all = {
#     Name = "nomaosdb"
#   }
# }

# # __generated__ by Terraform from "nginx-error"
# resource "aws_cloudwatch_log_group" "legacy_nginx_error" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "nginx-error"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "/nomaos/staging/api"
# resource "aws_cloudwatch_log_group" "legacy_nomaos_staging_api" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/nomaos/staging/api"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "ami-0f00a1ff1492a226d"
# resource "aws_ami" "legacy_ami_0f00a1ff1492a226d" {
#   architecture        = "x86_64"
#   boot_mode           = "uefi-preferred"
#   deprecation_time    = null
#   description         = null
#   ena_support         = true
#   image_location      = "353833416626/nomagx"
#   imds_support        = null
#   kernel_id           = null
#   name                = "nomagx"
#   ramdisk_id          = null
#   root_device_name    = "/dev/sda1"
#   sriov_net_support   = "simple"
#   tags                = {}
#   tags_all            = {}
#   tpm_support         = null
#   uefi_data           = null
#   virtualization_type = "hvm"
#   ebs_block_device {
#     delete_on_termination = true
#     device_name           = "/dev/sda1"
#     encrypted             = false
#     iops                  = 3000
#     outpost_arn           = null
#     snapshot_id           = "snap-008f1c1a56ca251b7"
#     throughput            = 125
#     volume_size           = 500
#     volume_type           = "gp3"
#   }
# }

# # __generated__ by Terraform
# resource "aws_subnet" "legacy_subnet_0309fc43ea380ad6b" {
#   assign_ipv6_address_on_creation                = false
#   availability_zone                              = "eu-west-1b"
#   availability_zone_id                           = "euw1-az3"
#   cidr_block                                     = "172.96.1.0/24"
#   customer_owned_ipv4_pool                       = null
#   enable_dns64                                   = false
#   enable_lni_at_device_index                     = 0
#   enable_resource_name_dns_a_record_on_launch    = false
#   enable_resource_name_dns_aaaa_record_on_launch = false
#   ipv6_cidr_block                                = null
#   ipv6_native                                    = false
#   map_customer_owned_ip_on_launch                = false
#   map_public_ip_on_launch                        = true
#   outpost_arn                                    = null
#   private_dns_hostname_type_on_launch            = "ip-name"
#   tags = {
#     Name                  = "agrovesto-infra-deployment/agrovesto-vpc/publicSubnet2"
#     "aws-cdk:subnet-name" = "public"
#     "aws-cdk:subnet-type" = "Public"
#   }
#   tags_all = {
#     Name                  = "agrovesto-infra-deployment/agrovesto-vpc/publicSubnet2"
#     "aws-cdk:subnet-name" = "public"
#     "aws-cdk:subnet-type" = "Public"
#   }
#   vpc_id = "vpc-0d9b566c353787d53"
# }

# # __generated__ by Terraform from "codepipeline-eu-west-1-3bf3ec101df5-4d09-9689-376482a069ed"
# resource "aws_s3_bucket" "legacy_codepipeline_eu_west_1_3bf3ec101df5_4d09_9689_376482a069ed" {
#   bucket              = "codepipeline-eu-west-1-3bf3ec101df5-4d09-9689-376482a069ed"
#   bucket_prefix       = null
#   force_destroy       = null
#   object_lock_enabled = false
#   tags                = {}
#   tags_all            = {}
# }

# # __generated__ by Terraform
# resource "aws_lambda_function" "legacy_agrovestoinfradeploymentagxdbrotationsingleuser096353c8" {
#   architectures                      = ["x86_64"]
#   code_signing_config_arn            = null
#   description                        = "Rotates a Secrets Manager secret for Amazon RDS SQL Server credentials using the single user rotation strategy."
#   filename                           = "legacy_lambda_placeholder.zip"
#   function_name                      = "agrovestoinfradeploymentagxdbRotationSingleUser096353C8"
#   handler                            = "lambda_function.lambda_handler"
#   image_uri                          = null
#   kms_key_arn                        = null
#   layers                             = []
#   memory_size                        = 128
#   package_type                       = "Zip"
#   publish                            = null
#   replace_security_groups_on_destroy = null
#   replacement_security_group_ids     = null
#   reserved_concurrent_executions     = -1
#   role                               = "arn:aws:iam::353833416626:role/agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-DTg5g94z5aY6"
#   runtime                            = "python3.10"
#   s3_bucket                          = null
#   s3_key                             = null
#   s3_object_version                  = null
#   skip_destroy                       = false
#   source_code_hash                   = null
#   tags = {
#     Name                             = "agxdb"
#     SecretsManagerLambda             = "Rotation"
#     "lambda:createdBy"               = "SAM"
#     "serverlessrepo:applicationId"   = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSSQLServerRotationSingleUser"
#     "serverlessrepo:semanticVersion" = "1.1.618"
#   }
#   tags_all = {
#     Name                             = "agxdb"
#     SecretsManagerLambda             = "Rotation"
#     "lambda:createdBy"               = "SAM"
#     "serverlessrepo:applicationId"   = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSSQLServerRotationSingleUser"
#     "serverlessrepo:semanticVersion" = "1.1.618"
#   }
#   timeout = 30
#   environment {
#     variables = {
#       EXCLUDE_CHARACTERS         = "%+~`#$&*()|[]{}:;<>?!'/@\"\\"
#       EXCLUDE_LOWERCASE          = "false"
#       EXCLUDE_NUMBERS            = "false"
#       EXCLUDE_PUNCTUATION        = "false"
#       EXCLUDE_UPPERCASE          = "false"
#       PASSWORD_LENGTH            = "32"
#       REQUIRE_EACH_INCLUDED_TYPE = "true"
#       SECRETS_MANAGER_ENDPOINT   = "https://secretsmanager.eu-west-1.amazonaws.com"
#     }
#   }
#   ephemeral_storage {
#     size = 512
#   }
#   logging_config {
#     application_log_level = null
#     log_format            = "Text"
#     log_group             = "/aws/lambda/agrovestoinfradeploymentagxdbRotationSingleUser096353C8"
#     system_log_level      = null
#   }
#   tracing_config {
#     mode = "PassThrough"
#   }
#   vpc_config {
#     ipv6_allowed_for_dual_stack = false
#     security_group_ids          = ["sg-039c167fa924e64ee"]
#     subnet_ids                  = ["subnet-004a7f9d9cbd53ea4", "subnet-0304d72cd90dd43d9"]
#   }
#   lifecycle {
#     ignore_changes = [filename, source_code_hash]
#   }
# }

# # __generated__ by Terraform
# resource "aws_lambda_function" "legacy_test" {
#   architectures                      = ["x86_64"]
#   code_signing_config_arn            = null
#   description                        = null
#   filename                           = "legacy_lambda_placeholder.zip"
#   function_name                      = "test"
#   handler                            = "LambdaTest::LambdaTest.LambdaHandler::handleRequest"
#   image_uri                          = null
#   kms_key_arn                        = null
#   layers                             = []
#   memory_size                        = 512
#   package_type                       = "Zip"
#   publish                            = null
#   replace_security_groups_on_destroy = null
#   replacement_security_group_ids     = null
#   reserved_concurrent_executions     = -1
#   role                               = "arn:aws:iam::353833416626:role/service-role/test-role-dfn63jmf"
#   runtime                            = "dotnet8"
#   s3_bucket                          = null
#   s3_key                             = null
#   s3_object_version                  = null
#   skip_destroy                       = false
#   source_code_hash                   = null
#   tags                               = {}
#   tags_all                           = {}
#   timeout                            = 15
#   ephemeral_storage {
#     size = 512
#   }
#   logging_config {
#     application_log_level = null
#     log_format            = "Text"
#     log_group             = "/aws/lambda/test"
#     system_log_level      = null
#   }
#   tracing_config {
#     mode = "PassThrough"
#   }
#   vpc_config {
#     ipv6_allowed_for_dual_stack = false
#     security_group_ids          = ["sg-0f106ece0245137c6"]
#     subnet_ids                  = ["subnet-05033c32cfcac40ce", "subnet-05b857da1bb60981f"]
#   }
#   lifecycle {
#     ignore_changes = [filename, source_code_hash]
#   }
# }

# # __generated__ by Terraform from "rtb-0fea2a4ff5a3adf0f"
# resource "aws_route_table" "legacy_rtb_0fea2a4ff5a3adf0f" {
#   propagating_vgws = []
#   route            = []
#   tags = {
#     Name = "agrovesto-infra-deployment/agrovesto-vpc/privateSubnet2"
#   }
#   tags_all = {
#     Name = "agrovesto-infra-deployment/agrovesto-vpc/privateSubnet2"
#   }
#   vpc_id = "vpc-0d9b566c353787d53"
# }

# # __generated__ by Terraform from "/aws/rds/instance/nomaos/agent"
# resource "aws_cloudwatch_log_group" "legacy_aws_rds_instance_nomaos_agent" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/rds/instance/nomaos/agent"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "/aws/lambda/amplify-reactvitetailwind-TableManagerCustomProvid-KHb5ED3lfMmU"
# resource "aws_cloudwatch_log_group" "legacy_aws_lambda_amplify_reactvitetailwind_tablemanagercustomprovi" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/lambda/amplify-reactvitetailwind-TableManagerCustomProvid-KHb5ED3lfMmU"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "sg-039c167fa924e64ee"
# resource "aws_security_group" "legacy_sg_039c167fa924e64ee" {
#   description = "agrovesto-infra-deployment/agxdb/RotationSingleUser/SecurityGroup"
#   egress = [{
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "Allow all outbound traffic by default"
#     from_port        = 0
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "-1"
#     security_groups  = []
#     self             = false
#     to_port          = 0
#   }]
#   ingress                = []
#   name                   = "agrovesto-infra-deployment-agxdbRotationSingleUserSecurityGroup123C71F0-McU6rttEQzRh"
#   name_prefix            = null
#   revoke_rules_on_delete = null
#   tags = {
#     Name = "agxdb"
#   }
#   tags_all = {
#     Name = "agxdb"
#   }
#   vpc_id = "vpc-0d9b566c353787d53"
# }

# # __generated__ by Terraform from "nginx-access"
# resource "aws_cloudwatch_log_group" "legacy_nginx_access" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "nginx-access"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform from "ec2-auth"
# resource "aws_cloudwatch_log_group" "legacy_ec2_auth" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "ec2-auth"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform
# resource "aws_instance" "legacy_i_00af32231113d64f9" {
#   ami                                  = "ami-027ec10fb80d5b0aa"
#   associate_public_ip_address          = true
#   availability_zone                    = "eu-west-1a"
#   disable_api_stop                     = false
#   disable_api_termination              = false
#   ebs_optimized                        = true
#   enable_primary_ipv6                  = null
#   get_password_data                    = false
#   hibernation                          = false
#   host_id                              = null
#   host_resource_group_arn              = null
#   iam_instance_profile                 = "ssmrole"
#   instance_initiated_shutdown_behavior = "stop"
#   instance_type                        = "t3.medium"
#   key_name                             = "noma-api"
#   monitoring                           = true
#   placement_group                      = null
#   placement_partition_number           = 0
#   private_ip                           = "172.96.0.254"
#   secondary_private_ips                = []
#   security_groups                      = []
#   source_dest_check                    = true
#   subnet_id                            = "subnet-0739cfd4c412deb3f"
#   tags = {
#     Name = "new-noma-api"
#   }
#   tags_all = {
#     Name = "new-noma-api"
#   }
#   tenancy                     = "default"
#   user_data                   = null
#   user_data_base64            = null
#   user_data_replace_on_change = null
#   volume_tags                 = null
#   vpc_security_group_ids      = ["sg-002ee2d53f67176cb", "sg-05943db64467559f0", "sg-0d8184650fd775043"]
#   capacity_reservation_specification {
#     capacity_reservation_preference = "open"
#   }
#   cpu_options {
#     amd_sev_snp      = null
#     core_count       = 1
#     threads_per_core = 2
#   }
#   credit_specification {
#     cpu_credits = "unlimited"
#   }
#   enclave_options {
#     enabled = false
#   }
#   maintenance_options {
#     auto_recovery = "default"
#   }
#   metadata_options {
#     http_endpoint               = "enabled"
#     http_protocol_ipv6          = "disabled"
#     http_put_response_hop_limit = 1
#     http_tokens                 = "optional"
#     instance_metadata_tags      = "disabled"
#   }
#   private_dns_name_options {
#     enable_resource_name_dns_a_record    = false
#     enable_resource_name_dns_aaaa_record = false
#     hostname_type                        = "ip-name"
#   }
#   root_block_device {
#     delete_on_termination = false
#     encrypted             = false
#     iops                  = 1500
#     kms_key_id            = null
#     tags                  = {}
#     tags_all              = {}
#     throughput            = 0
#     volume_size           = 500
#     volume_type           = "gp2"
#   }
# }

# # __generated__ by Terraform from "sg-003093b317e5032f7"
# resource "aws_security_group" "legacy_sg_003093b317e5032f7" {
#   description = "agrovesto-infra-deployment/nomaosdb/RotationSingleUser/SecurityGroup"
#   egress = [{
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "Allow all outbound traffic by default"
#     from_port        = 0
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     protocol         = "-1"
#     security_groups  = []
#     self             = false
#     to_port          = 0
#   }]
#   ingress                = []
#   name                   = "agrovesto-infra-deployment-nomaosdbRotationSingleUserSecurityGroup1AEE7A58-Ni5EFxUZ0sCg"
#   name_prefix            = null
#   revoke_rules_on_delete = null
#   tags = {
#     Name = "nomaosdb"
#   }
#   tags_all = {
#     Name = "nomaosdb"
#   }
#   vpc_id = "vpc-0d9b566c353787d53"
# }

# # __generated__ by Terraform from "ec2-cloud-init"
# resource "aws_cloudwatch_log_group" "legacy_ec2_cloud_init" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "ec2-cloud-init"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }

# # __generated__ by Terraform
# resource "aws_lambda_function" "legacy_agrovestoinfradeploymentnomaosdbrotationsingleuser77906076" {
#   architectures                      = ["x86_64"]
#   code_signing_config_arn            = null
#   description                        = "Rotates a Secrets Manager secret for Amazon RDS SQL Server credentials using the single user rotation strategy."
#   filename                           = "legacy_lambda_placeholder.zip"
#   function_name                      = "agrovestoinfradeploymentnomaosdbRotationSingleUser77906076"
#   handler                            = "lambda_function.lambda_handler"
#   image_uri                          = null
#   kms_key_arn                        = null
#   layers                             = []
#   memory_size                        = 128
#   package_type                       = "Zip"
#   publish                            = null
#   replace_security_groups_on_destroy = null
#   replacement_security_group_ids     = null
#   reserved_concurrent_executions     = -1
#   role                               = "arn:aws:iam::353833416626:role/agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-EXyHA0Ipenan"
#   runtime                            = "python3.10"
#   s3_bucket                          = null
#   s3_key                             = null
#   s3_object_version                  = null
#   skip_destroy                       = false
#   source_code_hash                   = null
#   tags = {
#     Name                             = "nomaosdb"
#     SecretsManagerLambda             = "Rotation"
#     "lambda:createdBy"               = "SAM"
#     "serverlessrepo:applicationId"   = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSSQLServerRotationSingleUser"
#     "serverlessrepo:semanticVersion" = "1.1.618"
#   }
#   tags_all = {
#     Name                             = "nomaosdb"
#     SecretsManagerLambda             = "Rotation"
#     "lambda:createdBy"               = "SAM"
#     "serverlessrepo:applicationId"   = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSSQLServerRotationSingleUser"
#     "serverlessrepo:semanticVersion" = "1.1.618"
#   }
#   timeout = 30
#   environment {
#     variables = {
#       EXCLUDE_CHARACTERS         = "%+~`#$&*()|[]{}:;<>?!'/@\"\\"
#       EXCLUDE_LOWERCASE          = "false"
#       EXCLUDE_NUMBERS            = "false"
#       EXCLUDE_PUNCTUATION        = "false"
#       EXCLUDE_UPPERCASE          = "false"
#       PASSWORD_LENGTH            = "32"
#       REQUIRE_EACH_INCLUDED_TYPE = "true"
#       SECRETS_MANAGER_ENDPOINT   = "https://secretsmanager.eu-west-1.amazonaws.com"
#     }
#   }
#   ephemeral_storage {
#     size = 512
#   }
#   logging_config {
#     application_log_level = null
#     log_format            = "Text"
#     log_group             = "/aws/lambda/agrovestoinfradeploymentnomaosdbRotationSingleUser77906076"
#     system_log_level      = null
#   }
#   tracing_config {
#     mode = "PassThrough"
#   }
#   vpc_config {
#     ipv6_allowed_for_dual_stack = false
#     security_group_ids          = ["sg-003093b317e5032f7"]
#     subnet_ids                  = ["subnet-004a7f9d9cbd53ea4", "subnet-0304d72cd90dd43d9"]
#   }
#   lifecycle {
#     ignore_changes = [filename, source_code_hash]
#   }
# }

# # __generated__ by Terraform from "Infra-ECS-Cluster-agrovesto-dev-aeff3897"
# resource "aws_cloudformation_stack" "legacy_infra_ecs_cluster_agrovesto_dev_aeff3897" {
#   capabilities      = ["CAPABILITY_NAMED_IAM"]
#   disable_rollback  = false
#   iam_role_arn      = null
#   name              = "Infra-ECS-Cluster-agrovesto-dev-aeff3897"
#   notification_arns = null
#   on_failure        = null
#   parameters        = {}
#   policy_body       = null
#   policy_url        = null
#   tags              = {}
#   tags_all          = {}
#   template_body = jsonencode({
#     AWSTemplateFormatVersion = "2010-09-09"
#     Description              = "The template used to create an ECS Cluster from the ECS Console."
#     Outputs = {
#       ECSCluster = {
#         Description = "The created cluster."
#         Value = {
#           Ref = "ECSCluster"
#         }
#       }
#     }
#     Parameters = {
#       ECSClusterName = {
#         Default     = "agrovesto-dev"
#         Description = "Specifies the ECS Cluster Name with which the resources would be associated"
#         Type        = "String"
#       }
#       SecurityGroupIds = {
#         Default     = ""
#         Description = "Optional - Specifies the Comma separated list of the Security Group Id of an existing Security Group."
#         Type        = "CommaDelimitedList"
#       }
#       SubnetIds = {
#         Default     = ""
#         Description = "Optional - Specifies the Comma separated list of existing VPC Subnet Ids where ECS instances will run"
#         Type        = "CommaDelimitedList"
#       }
#       VpcId = {
#         AllowedPattern        = "^(?:vpc-[0-9a-f]{8,17}|)$"
#         ConstraintDescription = "VPC Id must begin with 'vpc-' and have a valid uuid"
#         Default               = ""
#         Description           = "Optional - Specifies the ID of an existing VPC in which to launch your container instances. If you specify a VPC ID, you must specify a list of existing subnets in that VPC. If you do not specify a VPC ID, a new VPC is created with at least 1 subnet."
#         Type                  = "String"
#       }
#     }
#     Resources = {
#       ECSCluster = {
#         Properties = {
#           CapacityProviders = ["FARGATE", "FARGATE_SPOT"]
#           ClusterName = {
#             Ref = "ECSClusterName"
#           }
#           ClusterSettings = [{
#             Name  = "containerInsights"
#             Value = "enhanced"
#           }]
#           Configuration = {
#             ExecuteCommandConfiguration = {
#               Logging = "DEFAULT"
#             }
#           }
#           Tags = []
#         }
#         Type = "AWS::ECS::Cluster"
#       }
#     }
#   })
#   template_url       = null
#   timeout_in_minutes = 0
# }

# # __generated__ by Terraform
# resource "aws_instance" "legacy_i_050358d69e4220585" {
#   ami                                  = "ami-0de864d6a3bd20ea8"
#   associate_public_ip_address          = false
#   availability_zone                    = "eu-west-1a"
#   disable_api_stop                     = false
#   disable_api_termination              = false
#   ebs_optimized                        = false
#   enable_primary_ipv6                  = null
#   get_password_data                    = false
#   hibernation                          = false
#   host_id                              = null
#   host_resource_group_arn              = null
#   iam_instance_profile                 = "ssmrole"
#   instance_initiated_shutdown_behavior = "stop"
#   instance_type                        = "t2.micro"
#   key_name                             = "noma-api"
#   monitoring                           = false
#   placement_group                      = null
#   placement_partition_number           = 0
#   private_ip                           = "172.96.0.134"
#   secondary_private_ips                = []
#   security_groups                      = []
#   source_dest_check                    = true
#   subnet_id                            = "subnet-0739cfd4c412deb3f"
#   tags = {
#     Name = "rescue"
#   }
#   tags_all = {
#     Name = "rescue"
#   }
#   tenancy                     = "default"
#   user_data                   = null
#   user_data_base64            = null
#   user_data_replace_on_change = null
#   volume_tags                 = null
#   vpc_security_group_ids      = ["sg-05943db64467559f0"]
#   capacity_reservation_specification {
#     capacity_reservation_preference = "open"
#   }
#   cpu_options {
#     amd_sev_snp      = null
#     core_count       = 1
#     threads_per_core = 1
#   }
#   credit_specification {
#     cpu_credits = "standard"
#   }
#   enclave_options {
#     enabled = false
#   }
#   maintenance_options {
#     auto_recovery = "default"
#   }
#   metadata_options {
#     http_endpoint               = "enabled"
#     http_protocol_ipv6          = "disabled"
#     http_put_response_hop_limit = 2
#     http_tokens                 = "required"
#     instance_metadata_tags      = "disabled"
#   }
#   private_dns_name_options {
#     enable_resource_name_dns_a_record    = false
#     enable_resource_name_dns_aaaa_record = false
#     hostname_type                        = "ip-name"
#   }
#   root_block_device {
#     delete_on_termination = false
#     encrypted             = false
#     iops                  = 3000
#     kms_key_id            = null
#     tags                  = {}
#     tags_all              = {}
#     throughput            = 125
#     volume_size           = 8
#     volume_type           = "gp3"
#   }
# }

# # __generated__ by Terraform from "nomaos"
# resource "aws_ecr_repository" "legacy_nomaos" {
#   force_delete         = null
#   image_tag_mutability = "MUTABLE"
#   name                 = "nomaos"
#   tags                 = {}
#   tags_all             = {}
#   encryption_configuration {
#     encryption_type = "AES256"
#     kms_key         = null
#   }
#   image_scanning_configuration {
#     scan_on_push = true
#   }
# }

# # __generated__ by Terraform from "agrovesto-storage-dev"
# resource "aws_s3_bucket" "legacy_agrovesto_storage_dev" {
#   bucket              = "agrovesto-storage-dev"
#   bucket_prefix       = null
#   force_destroy       = null
#   object_lock_enabled = false
#   tags                = {}
#   tags_all            = {}
# }

# # __generated__ by Terraform from "nomaos-tfstate-logs-353833416626-eu-west-1"
# resource "aws_s3_bucket" "legacy_nomaos_tfstate_logs_353833416626_eu_west_1" {
#   bucket              = "nomaos-tfstate-logs-353833416626-eu-west-1"
#   bucket_prefix       = null
#   force_destroy       = null
#   object_lock_enabled = false
#   tags = {
#     Component = "bootstrap"
#     ManagedBy = "Terraform"
#     Project   = "nomaos"
#   }
#   tags_all = {
#     Component   = "bootstrap"
#     Environment = "dev"
#     ManagedBy   = "Terraform"
#     Project     = "nomaos"
#   }
# }

# # __generated__ by Terraform from "/aws/lambda/agrovestoinfradeploymentnomaosdbRotationSingleUser77906076"
# resource "aws_cloudwatch_log_group" "legacy_aws_lambda_agrovestoinfradeploymentnomaosdbrotationsingleuse" {
#   kms_key_id        = null
#   log_group_class   = "STANDARD"
#   name              = "/aws/lambda/agrovestoinfradeploymentnomaosdbRotationSingleUser77906076"
#   name_prefix       = null
#   retention_in_days = 0
#   skip_destroy      = false
#   tags              = {}
#   tags_all          = {}
# }
