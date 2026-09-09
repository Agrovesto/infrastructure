# Schema-aware mock values only. No AWS credentials, state backend or API calls.
# ARNs are synthetic fixtures, not deployable configuration.
mock_data "aws_iam_policy_document" {
  defaults = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Deny\",\"Action\":\"s3:DeleteBucket\",\"Resource\":\"*\",\"Principal\":\"*\"}]}"
  }
}
mock_data "aws_ami" {
  defaults = { id = "ami-0123456789abcdef0" }
}
mock_data "aws_rds_engine_version" {
  defaults = { version = "16.00.4215.2.v1", version_actual = "16.00.4215.2.v1" }
}
mock_data "aws_route53_zone" {
  defaults = { zone_id = "Z123456789EXAMPLE", name = "dev.example.com.", private_zone = false, name_servers = ["ns-1.example.net", "ns-2.example.net", "ns-3.example.net", "ns-4.example.net"] }
}
mock_resource "aws_kms_key" {
  defaults = { arn = "arn:aws:kms:eu-west-1:111111111111:key/11111111-1111-1111-1111-111111111111", key_id = "11111111-1111-1111-1111-111111111111" }
}
mock_resource "aws_s3_bucket" {
  defaults = { id = "agrovesto-fixture", arn = "arn:aws:s3:::agrovesto-fixture" }
}
mock_resource "aws_iam_role" {
  defaults = { arn = "arn:aws:iam::111111111111:role/agrovesto-fixture" }
}
mock_resource "aws_iam_policy" {
  defaults = { arn = "arn:aws:iam::111111111111:policy/agrovesto-fixture" }
}
mock_resource "aws_iam_openid_connect_provider" {
  defaults = { arn = "arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com" }
}
mock_resource "aws_iam_instance_profile" {
  defaults = { arn = "arn:aws:iam::111111111111:instance-profile/agrovesto-fixture" }
}
mock_resource "aws_cloudwatch_log_group" {
  defaults = { arn = "arn:aws:logs:eu-west-1:111111111111:log-group:/agrovesto-fixture" }
}
mock_resource "aws_sns_topic" {
  defaults = { arn = "arn:aws:sns:eu-west-1:111111111111:agrovesto-fixture" }
}
mock_resource "aws_cloudwatch_event_rule" {
  defaults = { arn = "arn:aws:events:eu-west-1:111111111111:rule/agrovesto-fixture" }
}
mock_resource "aws_secretsmanager_secret" {
  defaults = { arn = "arn:aws:secretsmanager:eu-west-1:111111111111:secret:agrovesto-fixture-AbCdEf" }
}
mock_resource "aws_vpc" {
  defaults = { id = "vpc-0123456789abcdef0" }
}
mock_resource "aws_subnet" {
  defaults = { id = "subnet-0123456789abcdef0" }
}
mock_resource "aws_security_group" {
  defaults = { id = "sg-0123456789abcdef0" }
}
mock_resource "aws_instance" {
  defaults = { id = "i-0123456789abcdef0", private_ip = "10.10.10.20" }
}
mock_resource "aws_ebs_volume" {
  defaults = { id = "vol-0123456789abcdef0", arn = "arn:aws:ec2:eu-west-1:111111111111:volume/vol-0123456789abcdef0" }
}
mock_resource "aws_backup_plan" {
  defaults = { id = "11111111-1111-1111-1111-111111111111" }
}
mock_resource "aws_backup_vault" {
  defaults = { arn = "arn:aws:backup:eu-west-1:111111111111:backup-vault:agrovesto-fixture" }
}
mock_resource "aws_ssm_document" {
  defaults = { latest_version = "1" }
}
mock_resource "aws_route53_zone" {
  defaults = { zone_id = "Z123456789EXAMPLE", name_servers = ["ns-1.example.net", "ns-2.example.net", "ns-3.example.net", "ns-4.example.net"] }
}
mock_resource "aws_acm_certificate" {
  defaults = {
    arn = "arn:aws:acm:eu-west-1:111111111111:certificate/11111111-1111-1111-1111-111111111111"
    domain_validation_options = [
      { domain_name = "example.com", resource_record_name = "_prod.example.com.", resource_record_type = "CNAME", resource_record_value = "_prod.acm-validations.aws." },
      { domain_name = "*.example.com", resource_record_name = "_prod.example.com.", resource_record_type = "CNAME", resource_record_value = "_prod.acm-validations.aws." },
      { domain_name = "dev.example.com", resource_record_name = "_dev.dev.example.com.", resource_record_type = "CNAME", resource_record_value = "_dev.acm-validations.aws." },
      { domain_name = "*.dev.example.com", resource_record_name = "_dev.dev.example.com.", resource_record_type = "CNAME", resource_record_value = "_dev.acm-validations.aws." }
    ]
  }
}
mock_resource "aws_route53_record" {
  defaults = { fqdn = "_validation.example.com." }
}
mock_resource "aws_lb" {
  defaults = { arn = "arn:aws:elasticloadbalancing:eu-west-1:111111111111:loadbalancer/app/agrovesto-fixture/1234567890123456", arn_suffix = "app/agrovesto-fixture/1234567890123456", dns_name = "agrovesto-fixture.eu-west-1.elb.amazonaws.com", zone_id = "Z123456789EXAMPLE" }
}
mock_resource "aws_lb_listener" {
  defaults = { arn = "arn:aws:elasticloadbalancing:eu-west-1:111111111111:listener/app/agrovesto-fixture/1234567890123456/1234567890123456" }
}
mock_resource "aws_lb_target_group" {
  defaults = { arn = "arn:aws:elasticloadbalancing:eu-west-1:111111111111:targetgroup/agrovesto-fixture/1234567890123456", arn_suffix = "targetgroup/agrovesto-fixture/1234567890123456" }
}
mock_resource "aws_db_instance" {
  defaults = {
    address            = "agrovesto-fixture.abcdef.eu-west-1.rds.amazonaws.com"
    master_user_secret = [{ secret_arn = "arn:aws:secretsmanager:eu-west-1:222222222222:secret:rds-fixture-AbCdEf", kms_key_id = "11111111-1111-1111-1111-111111111111", secret_status = "active" }]
  }
}
mock_resource "aws_ecs_cluster" {
  defaults = { id = "arn:aws:ecs:eu-west-1:222222222222:cluster/agrovesto-fixture", arn = "arn:aws:ecs:eu-west-1:222222222222:cluster/agrovesto-fixture" }
}
mock_resource "aws_ecs_task_definition" {
  defaults = { arn = "arn:aws:ecs:eu-west-1:222222222222:task-definition/agrovesto-fixture:1" }
}
mock_resource "aws_ecr_repository" {
  defaults = { arn = "arn:aws:ecr:eu-west-1:111111111111:repository/agrovesto/fixture", repository_url = "111111111111.dkr.ecr.eu-west-1.amazonaws.com/agrovesto/fixture" }
}
mock_resource "aws_amplify_app" {
  defaults = { id = "d1234567890123", default_domain = "d1234567890123.amplifyapp.com" }
}

mock_resource "aws_amplify_domain_association" {
  defaults = {
    certificate_verification_dns_record = "_amplify.portal.dev.example.com. CNAME _amplify.acm-validations.aws."
    sub_domain                          = [{ branch_name = "dev", prefix = "", dns_record = " CNAME d123example.cloudfront.net", verified = true }]
  }
}

mock_resource "aws_kms_alias" {
  defaults = { arn = "arn:aws:kms:eu-west-1:111111111111:alias/agrovesto-fixture" }
}
