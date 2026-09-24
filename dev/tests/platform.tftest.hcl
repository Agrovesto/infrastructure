# =============================================================================
# DEV — VPC, scheduler, S3 backups, ECR, Amplify, DNS
# (a single file: the dev stack is one flat root module with no for_each
# dependencies between these pieces)
# =============================================================================

mock_provider "aws" {}

override_data {
  target = data.aws_availability_zones.available
  values = {
    names = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  }
}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:root"
  }
}

override_data {
  target = data.aws_ami.ubuntu
  values = {
    id = "ami-0123456789abcdef0"
  }
}

override_data {
  target = data.aws_iam_policy_document.ec2_assume
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.ec2
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.scheduler_assume
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"scheduler.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.scheduler
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }
}

variables {
  import_existing = false

  ami_id            = "ami-0123456789abcdef0"
  domain_name       = "nomaos.com"
  mssql_sa_password = "Str0ng!TestOnly" # ggignore - test fixture, not a credential
  mssql_databases   = ["wallet", "onboarding", "input", "moneval", "serviceprovider"]

  apis = {
    wallet = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5001
      subdomain = "dev-wallet-api"
    }
    onboarding = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5002
      subdomain = "dev-onboarding-api"
    }
    input = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5003
      subdomain = "dev-input-api"
    }
    moneval = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5004
      subdomain = "dev-moneval-api"
    }
    serviceprovider = {
      image     = "public.ecr.aws/nginx/nginx:alpine"
      host_port = 5005
      subdomain = "dev-serviceprovider-api"
    }
  }

  amplify_apps = {
    landing = {
      repository = "https://github.com/Agrovesto/nomaos-landingpage"
      branch     = "dev"
      subdomain  = "dev-agrovesto"
      framework  = "React"
    }
    onboarding = {
      repository = "https://github.com/Agrovesto/onboarding-frontend"
      branch     = "dev"
      subdomain  = "onboarding-dev"
      framework  = "React"
    }
  }
}

# -----------------------------------------------------------------------------
# VPC — regression cover for the plan-time count fix
# -----------------------------------------------------------------------------

run "vpc" {
  command = plan

  assert {
    condition     = aws_vpc.main.cidr_block == "172.96.0.0/16"
    error_message = "Dev VPC is the adopted vpc-0d9b566c353787d53 (172.96.0.0/16); cidr_block is ForceNew."
  }

  assert {
    condition     = aws_vpc.main.enable_dns_support && aws_vpc.main.enable_dns_hostnames
    error_message = "DNS support + hostnames are required."
  }

  assert {
    condition     = length(aws_subnet.public) == 1
    error_message = "Dev has a single public subnet (no NAT gateway by design)."
  }

  # Regression: this was count = length(aws_subnet.public) (unknown until
  # apply) — it must stay derived from var.public_subnet_cidrs.
  assert {
    condition     = length(aws_route_table_association.public) == 1
    error_message = "The route table association count must be resolvable at plan time."
  }

  assert {
    condition     = aws_route.internet.destination_cidr_block == "0.0.0.0/0"
    error_message = "Public route table needs a default route through the IGW."
  }

  assert {
    condition     = length(aws_default_security_group.default[*].id) == 1
    error_message = "The default SG is stripped of its allow-all rules."
  }
}

# -----------------------------------------------------------------------------
# Start/stop scheduler (the biggest dev saving)
# -----------------------------------------------------------------------------

run "scheduler" {
  command = plan

  assert {
    condition     = aws_scheduler_schedule_group.ec2.name == "${var.project}-${var.environment}-ec2"
    error_message = "Schedule group follows the naming convention."
  }

  assert {
    condition     = aws_scheduler_schedule.start.state == "ENABLED"
    error_message = "enable_ec2_scheduler = true must leave the schedules enabled."
  }

  assert {
    condition     = aws_scheduler_schedule.start.schedule_expression == "cron(0 8 ? * MON-FRI *)"
    error_message = "The host starts at 08:00 on weekdays."
  }

  assert {
    condition     = aws_scheduler_schedule.stop.schedule_expression == "cron(0 20 ? * MON-FRI *)"
    error_message = "The host stops at 20:00 on weekdays."
  }

  assert {
    condition     = aws_scheduler_schedule.start.schedule_expression_timezone == "Africa/Lagos"
    error_message = "Schedules run in Africa/Lagos, not UTC."
  }
}

run "scheduler_disabled" {
  command = plan

  variables {
    enable_ec2_scheduler = false
  }

  assert {
    condition     = aws_scheduler_schedule.start.state == "DISABLED"
    error_message = "enable_ec2_scheduler = false must disable the start schedule."
  }

  assert {
    condition     = aws_scheduler_schedule.stop.state == "DISABLED"
    error_message = "enable_ec2_scheduler = false must disable the stop schedule."
  }
}

# -----------------------------------------------------------------------------
# Backup bucket
# -----------------------------------------------------------------------------

run "backup_bucket" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.backup.block_public_acls == true
    error_message = "The backup bucket must block public ACLs."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.backup.restrict_public_buckets == true
    error_message = "The backup bucket must restrict public access."
  }

  assert {
    condition     = [for v in aws_s3_bucket_versioning.backup.versioning_configuration : v.status] == ["Enabled"]
    error_message = "Versioning keeps accidental backup deletions recoverable."
  }

  assert {
    condition = flatten([
      for r in aws_s3_bucket_server_side_encryption_configuration.backup.rule : [
        for d in r.apply_server_side_encryption_by_default : d.sse_algorithm
      ]
    ]) == ["AES256"]
    error_message = "Backups must be encrypted at rest."
  }

  assert {
    condition = flatten([
      for r in aws_s3_bucket_lifecycle_configuration.backup.rule : [
        for e in r.expiration : e.days
      ]
    ]) == [14]
    error_message = "Backups expire after var.backup_retention_days (14)."
  }

  assert {
    condition = flatten([
      for r in aws_s3_bucket_lifecycle_configuration.backup.rule : [
        for n in r.noncurrent_version_expiration : n.noncurrent_days
      ]
    ]) == [7]
    error_message = "Non-current versions expire after 7 days."
  }
}

# -----------------------------------------------------------------------------
# ECR
# -----------------------------------------------------------------------------

run "ecr" {
  command = plan

  assert {
    condition     = length(aws_ecr_repository.apis) == 5
    error_message = "One repository per API."
  }

  assert {
    condition     = aws_ecr_repository.apis["wallet"].name == "${var.project}-${var.environment}-wallet"
    error_message = "Repository names follow <project>-<environment>-<service>."
  }

  assert {
    condition     = aws_ecr_repository.apis["wallet"].image_tag_mutability == "MUTABLE"
    error_message = "Dev allows re-pushing :latest freely (prod is IMMUTABLE)."
  }

  assert {
    condition     = aws_ecr_repository.apis["wallet"].image_scanning_configuration[0].scan_on_push == true
    error_message = "Scan on push must stay enabled."
  }

  assert {
    condition     = length(aws_ecr_lifecycle_policy.apis) == 5
    error_message = "Every repository needs a lifecycle policy."
  }
}

# -----------------------------------------------------------------------------
# Amplify frontends
# -----------------------------------------------------------------------------

run "amplify" {
  command = plan

  assert {
    condition     = length(aws_amplify_app.this) == 2
    error_message = "One Amplify app per entry in var.amplify_apps."
  }

  assert {
    condition     = aws_amplify_app.this["landing"].platform == "WEB"
    error_message = "Amplify apps are WEB platform."
  }

  assert {
    condition     = aws_amplify_branch.this["landing"].branch_name == "dev"
    error_message = "Branches track the branch configured in var.amplify_apps."
  }

  assert {
    condition     = aws_amplify_branch.this["onboarding"].branch_name == "dev"
    error_message = "Branches track the branch configured in var.amplify_apps."
  }

  assert {
    condition     = length(aws_amplify_domain_association.this) == 0
    error_message = "Custom domains stay off unless amplify_enable_custom_domain = true."
  }
}

run "amplify_custom_domains" {
  command = plan

  variables {
    amplify_enable_custom_domain = true
  }

  assert {
    condition     = length(aws_amplify_domain_association.this) == 2
    error_message = "Custom domain associations are created per app when enabled."
  }
}

# -----------------------------------------------------------------------------
# DNS — owned by prod, so dev creates nothing by default
# -----------------------------------------------------------------------------

run "dns_managed_by_prod" {
  command = plan

  variables {
    manage_dns = false
  }

  assert {
    condition     = length(aws_route53_zone.this) == 0
    error_message = "manage_dns = false: dev creates no hosted zone (prod owns the root domain)."
  }

  assert {
    condition     = length(aws_route53_record.a) == 0
    error_message = "manage_dns = false: no A records from the dev stack."
  }

  assert {
    condition     = length(aws_route53_record.cname) == 0
    error_message = "manage_dns = false: no CNAME records from the dev stack."
  }
}

run "dns_managed_by_dev" {
  command = plan

  variables {
    manage_dns = true
  }

  assert {
    condition     = length(aws_route53_zone.this) == 1
    error_message = "manage_dns = true creates the zone for var.domain_name."
  }

  # 5 APIs + vault + mssql
  assert {
    condition     = length(aws_route53_record.a) == 7
    error_message = "Every API plus vault and mssql get an A record to the EC2 host."
  }

  assert {
    condition     = toset(keys(aws_route53_record.a)) == toset(["dev-input-api", "dev-moneval-api", "dev-onboarding-api", "dev-serviceprovider-api", "dev-wallet-api", "mssql", "vault"])
    error_message = "A record keys are the API subdomains plus vault and mssql."
  }

  assert {
    condition     = length(aws_route53_record.cname) == 2
    error_message = "One CNAME per Amplify app."
  }
}

# -----------------------------------------------------------------------------
# Remaining network, storage and IAM wiring
# -----------------------------------------------------------------------------

run "network_edges" {
  command = plan

  assert {
    condition     = aws_internet_gateway.main.tags["Name"] == "${var.project}-${var.environment}-igw"
    error_message = "The IGW keeps its convention name (adopted igw-04e4d65d903b2b67d is renamed in place)."
  }

  assert {
    condition     = aws_route_table.public.tags["Name"] == "${var.project}-${var.environment}-public-rt"
    error_message = "The public route table keeps its convention name."
  }
}

run "storage_buckets_and_volumes" {
  command = plan

  assert {
    condition     = aws_s3_bucket.backup.bucket == "${var.project}-${var.environment}-mssql-backups" && aws_s3_bucket.backup.tags["Purpose"] == "mssql-backup"
    error_message = "The backup bucket follows <project>-<env>-mssql-backups."
  }

  assert {
    condition     = aws_s3_bucket.host_config.bucket == "${var.project}-${var.environment}-host-config" && aws_s3_bucket.host_config.force_destroy
    error_message = "Host config is reproducible from the repo, so its bucket may be force-destroyed."
  }

  assert {
    condition     = aws_volume_attachment.mssql.device_name == "/dev/sdf"
    error_message = "The MSSQL data volume attaches at var.mssql_volume_device (/dev/sdf), which user_data mounts."
  }
}

run "scheduler_iam" {
  command = plan

  assert {
    condition     = aws_iam_role.scheduler.name == "${var.project}-${var.environment}-ec2-scheduler-role"
    error_message = "The scheduler role keeps its convention name."
  }

  assert {
    condition     = aws_iam_role_policy.scheduler.name == "${var.project}-${var.environment}-scheduler-policy"
    error_message = "The scheduler policy is attached and is valid JSON."
  }
}

run "extra_alias_records" {
  command = plan

  variables {
    manage_dns = true
    extra_alias_records = {
      "@" = { name = "d111111abcdef8.cloudfront.net", zone_id = "Z2FDTNDATAQYW2" }
      www = { name = "d111111abcdef8.cloudfront.net", zone_id = "Z2FDTNDATAQYW2", evaluate_target_health = true }
    }
  }

  assert {
    condition     = aws_route53_record.alias["@"].name == "nomaos.com" && aws_route53_record.alias["www"].name == "www.nomaos.com"
    error_message = "\"@\" maps to the apex; other keys become subdomains."
  }

  assert {
    condition     = one(aws_route53_record.alias["www"].alias).evaluate_target_health && !one(aws_route53_record.alias["@"].alias).evaluate_target_health
    error_message = "evaluate_target_health defaults to false and can be turned on per record."
  }
}

# --- Rekognition --------------------------------------------------------------
run "rekognition" {
  # plan: a full mocked apply of the dev stack feeds random strings into ARN
  # fields (alarms, scheduler, SNS), which the provider rejects.
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.rekognition.versioning_configuration[0].status == "Enabled"
    error_message = "The media bucket is versioned (old versions expire after 7 days)."
  }
  assert {
    condition     = [for c in aws_rekognition_collection.this : c.collection_id] == ["${local.name}-customers"]
    error_message = "One KYC face collection by default, named after the stack."
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.rekognition.block_public_acls &&
      aws_s3_bucket_public_access_block.rekognition.restrict_public_buckets &&
      aws_s3_bucket_ownership_controls.rekognition.rule[0].object_ownership == "BucketOwnerEnforced" &&
      one(aws_s3_bucket_server_side_encryption_configuration.rekognition.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    )
    error_message = "The media bucket is private and encrypted."
  }

  assert {
    condition     = startswith(aws_s3_bucket.rekognition.bucket, "${local.name}-rekognition-") && aws_s3_bucket_policy.rekognition != null
    error_message = "The media bucket is account-scoped and TLS-only."
  }

  assert {
    condition = contains([
      for r in aws_s3_bucket_lifecycle_configuration.rekognition.rule : r.expiration[0].days if r.id == "expire-liveness-audit-images"
    ], 30)
    error_message = "Liveness audit images expire after 30 days by default."
  }

  assert {
    condition = (
      aws_sns_topic.rekognition_video.name == "${local.name}-rekognition-video" &&
      aws_sns_topic_subscription.rekognition_video.protocol == "sqs" &&
      aws_sns_topic_subscription.rekognition_video.raw_message_delivery &&
      aws_sqs_queue.rekognition_video.sqs_managed_sse_enabled &&
      aws_sqs_queue.rekognition_video_dlq.message_retention_seconds == 1209600 &&
      aws_sqs_queue_policy.rekognition_video != null
    )
    error_message = "Video job status flows SNS -> encrypted SQS with a DLQ."
  }

  assert {
    condition     = aws_iam_role.rekognition_video.name == "${local.name}-rekognition-video" && aws_iam_role_policy.rekognition_video.name == "publish-job-status"
    error_message = "Rekognition publishes video job status through its own role."
  }

  assert {
    condition = (
      length(aws_cognito_identity_pool.liveness) == 1 &&
      aws_cognito_identity_pool.liveness[0].allow_unauthenticated_identities &&
      !aws_cognito_identity_pool.liveness[0].allow_classic_flow &&
      length(aws_cognito_identity_pool_roles_attachment.liveness) == 1 &&
      strcontains(aws_iam_role_policy.liveness_guest[0].policy, "rekognition:StartFaceLivenessSession") &&
      !strcontains(aws_iam_role_policy.liveness_guest[0].policy, "Detect") &&
      aws_iam_role.liveness_guest[0].name == "${local.name}-rekognition-liveness-guest"
    )
    error_message = "Liveness guests can only stream a liveness session."
  }

  assert {
    condition     = aws_iam_role_policy.app_rekognition.name == "${local.name}-app-rekognition"
    error_message = "The application role gets the Rekognition policy."
  }
}

run "rekognition_minimal" {
  command = plan

  variables {
    rekognition = { collections = [], liveness_identity_pool = false }
  }

  assert {
    condition     = length(aws_rekognition_collection.this) == 0 && length(aws_cognito_identity_pool.liveness) == 0 && length(aws_iam_role.liveness_guest) == 0
    error_message = "Collections and the liveness guest pool are optional."
  }
}
