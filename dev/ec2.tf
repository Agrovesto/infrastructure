# =============================================================================
# EC2 app host — nginx reverse proxy + docker compose stack
# (7 APIs, HashiCorp Vault, SQL Server 2022)
# =============================================================================

resource "aws_instance" "app" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  ebs_optimized               = true
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = false
  key_name                    = var.key_name != "" ? var.key_name : null

  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = merge(local.tags, { Name = "${local.name}-os-apps" })
  }

  # Only bootstrap logic is in here. The rendered files themselves — compose
  # project, nginx.conf, the SQL bootstrap, the logging stack's config — are
  # objects in aws_s3_bucket.host_config and this script syncs them, because EC2
  # caps user data at 16 KB raw and none of that config belongs in metadata.
  # See dev/host_config.tf.
  # cloud-init runs this bootstrap only on first boot. It is deliberately NOT a
  # replacement trigger any more (see lifecycle.ignore_changes below): config
  # changes reach the running host through aws_ssm_association.host_config_refresh.
  # To rebuild the host on purpose (e.g. after rotating SSO credentials or to
  # pick up a newer Ubuntu AMI):  terraform apply -replace=aws_instance.app
  user_data_replace_on_change = false
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    mssql_volume_id = replace(aws_ebs_volume.mssql.id, "-", "")
    mssql_parameter = aws_ssm_parameter.mssql_sa_password.name
    backup_bucket   = aws_s3_bucket.backup.bucket
    aws_region      = var.aws_region
    ecr_registry    = local.ecr_registry
    # Every database that gets created, including SonarQube's, so the nightly
    # backup loop covers the same set init-dbs.sql does.
    db_list            = join(" ", local.mssql_all_databases)
    host_config_bucket = local.host_config_bucket

    vault             = var.vault
    vault_github_parameters = var.vault.oidc_enabled ? {
      client_id     = aws_ssm_parameter.vault_github_client_id[0].name
      client_secret = aws_ssm_parameter.vault_github_client_secret[0].name
      oidc_secret   = aws_ssm_parameter.vault_oidc_client_secret[0].name
    } : {}

    logging           = local.logging_runtime
    logging_root      = local.logging_root
    logging_volume_id = var.logging.enabled ? replace(aws_ebs_volume.logging[0].id, "-", "") : ""
    grafana_parameter = var.logging.enabled ? aws_ssm_parameter.grafana_admin_password[0].name : ""
    grafana_github_parameters = local.grafana_github_sso_enabled ? {
      client_id     = aws_ssm_parameter.grafana_github_client_id[0].name
      client_secret = aws_ssm_parameter.grafana_github_client_secret[0].name
    } : {}

    redis           = var.redis
    redis_parameter = var.redis.enabled && var.redis.password != "" ? aws_ssm_parameter.redis_password[0].name : ""

    sonarqube           = local.sonarqube_runtime
    sonar_web_baseurl   = local.sonar_web_baseurl
    sonarqube_volume_id = var.sonarqube.enabled ? replace(aws_ebs_volume.sonarqube[0].id, "-", "") : ""
    sonarqube_parameter = var.sonarqube.enabled ? aws_ssm_parameter.sonarqube_db_password[0].name : ""
    sonarqube_github_parameters = local.sonarqube_github_sso_enabled ? {
      client_id     = aws_ssm_parameter.sonarqube_github_client_id[0].name
      client_secret = aws_ssm_parameter.sonarqube_github_client_secret[0].name
      app_id        = aws_ssm_parameter.sonarqube_github_app_id[0].name
      private_key   = aws_ssm_parameter.sonarqube_github_private_key[0].name
    } : {}

    sso_proxy = local.github_sso_proxy
    sso_credential_versions = concat(
      local.sonarqube_github_sso_enabled ? [
        tostring(aws_ssm_parameter.sonarqube_github_client_id[0].version),
        tostring(aws_ssm_parameter.sonarqube_github_client_secret[0].version),
        tostring(aws_ssm_parameter.sonarqube_github_app_id[0].version),
        tostring(aws_ssm_parameter.sonarqube_github_private_key[0].version),
      ] : [],
      local.grafana_github_sso_enabled ? [
        tostring(aws_ssm_parameter.grafana_github_client_id[0].version),
        tostring(aws_ssm_parameter.grafana_github_client_secret[0].version),
      ] : [],
    )
  })

  # user_data learns the bucket as a rendered string, which is no dependency at
  # all, so say it explicitly: the sync has to find the objects already there.
  depends_on = [aws_s3_object.host_config, aws_iam_role_policy.ec2]

  lifecycle {
    # Keep the live host: Vault's /data/vault/data bind mount is confirmed on
    # the root EBS volume, which is delete_on_termination.
    prevent_destroy = true
    # A new Canonical AMI (most_recent = true) or any edit to the rendered
    # bootstrap would otherwise destroy and recreate the host on every apply.
    ignore_changes = [ami, user_data]

    precondition {
      condition     = !var.vault.oidc_enabled || var.vault_oidc_restart_ack
      error_message = "Enabling Vault OIDC restarts Vault on the EC2 root disk. Confirm a verified backup and current-seal restart plan (3 Shamir shares, or verified KMS auto-unseal) first (vault_oidc_restart_ack = true)."
    }

    precondition {
      condition     = !var.vault.oidc_enabled || local.vault_oidc_credentials_valid
      error_message = "Vault browser login requires GitHub OAuth ID/secret and a separate Dex OIDC client secret."
    }

    precondition {
      condition     = !var.vault.oidc_enabled || can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", var.vault_github_organization))
      error_message = "vault_github_organization must be a single GitHub organization login."
    }

    precondition {
      condition     = !var.vault.oidc_enabled || can(regex("^[a-z0-9]([a-z0-9-]{0,98}[a-z0-9])?$", var.vault_github_team_slug))
      error_message = "vault_github_team_slug must be a GitHub team slug."
    }

    precondition {
      condition     = local.sonarqube_github_configuration_valid
      error_message = "SonarQube GitHub SSO requires all four values (client ID, client secret, App ID and private key), or all four must be empty."
    }

    precondition {
      condition     = local.grafana_github_configuration_valid
      error_message = "Dev Grafana GitHub SSO requires both the client ID and client secret, or both must be empty."
    }

    precondition {
      condition     = !alltrue(local.grafana_github_credentials_set) || local.grafana_github_team_organizations_valid
      error_message = "Every dev Grafana GitHub team-role organization must also be present in grafana_github_organizations."
    }

    precondition {
      condition     = !alltrue(local.sonarqube_github_credentials_set) || (var.sonarqube.enabled && var.sonarqube.expose_via_nginx && length(var.sonarqube.allowed_cidrs) > 0)
      error_message = "SonarQube GitHub SSO needs SonarQube exposed through nginx and at least one explicit sonarqube.allowed_cidrs entry for browser callbacks."
    }

    precondition {
      condition     = !alltrue(local.grafana_github_credentials_set) || (var.logging.enabled && var.logging.expose_via_nginx && length(var.logging.allowed_cidrs) > 0)
      error_message = "Dev Grafana GitHub SSO needs Grafana exposed through nginx and at least one explicit logging.allowed_cidrs entry for browser callbacks."
    }
  }

  metadata_options {
    http_tokens = "required"
    # 2 hops so containers (Alertmanager -> SNS, APIs -> Rekognition/SNS) can
    # use the instance role through IMDSv2. Changes in place.
    http_put_response_hop_limit = 2
  }

  tags = merge(local.tags, { Name = "${local.name}-app-host" })
}

resource "aws_ebs_volume" "mssql" {
  availability_zone = aws_subnet.public[0].availability_zone
  size              = var.mssql_volume_size_gb
  type              = "gp3"
  encrypted         = true

  tags = merge(local.tags, { Name = "${local.name}-mssql-data" })
}

resource "aws_volume_attachment" "mssql" {
  device_name = var.mssql_volume_device
  volume_id   = aws_ebs_volume.mssql.id
  instance_id = aws_instance.app.id
}

resource "aws_eip" "app" {
  #checkov:skip=CKV2_AWS_19: EIP is attached to the EC2 host via aws_eip_association below (checkov does not follow that resource)
  count  = var.associate_elastic_ip ? 1 : 0
  domain = "vpc"

  tags = merge(local.tags, { Name = "${local.name}-eip" })
}

resource "aws_eip_association" "app" {
  count = var.associate_elastic_ip ? 1 : 0

  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app[0].id
}

# Push config changes to the running host instead of replacing it. The
# association re-runs whenever the rendered host config (the S3 objects) changes:
# it re-syncs /opt/agrovesto from S3 and runs `docker compose up -d`, which only
# recreates the containers whose definition actually changed.
resource "aws_ssm_association" "host_config_refresh" {
  name             = "AWS-RunShellScript"
  association_name = "${local.name}-host-config-refresh"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.app.id]
  }

  parameters = {
    commands = join("\n", concat([
      "# config hash: ${sha256(jsonencode({ for k, o in aws_s3_object.host_config : k => o.etag }))}",
      "# Vault OAuth parameter versions: ${var.vault.oidc_enabled ? join(",", [tostring(aws_ssm_parameter.vault_github_client_id[0].version), tostring(aws_ssm_parameter.vault_github_client_secret[0].version), tostring(aws_ssm_parameter.vault_oidc_client_secret[0].version)]) : "disabled"}",
      "set -euo pipefail",
    ], var.vault.oidc_enabled ? [
      # The existing systemd unit runs compose immediately after sync. Inject
      # SSM secrets and prepare Dex/Caddy state FIRST, then start the services.
      "aws s3 sync s3://${local.host_config_bucket}/ /opt/agrovesto --region ${var.aws_region} --only-show-errors",
      "bash /opt/agrovesto/scripts/refresh-vault-oidc.sh",
      "docker compose --project-directory /opt/agrovesto/compose -f /opt/agrovesto/compose/docker-compose.yml up -d --remove-orphans",
    ] : ["systemctl start agrovesto-sync.service"]))
  }

  depends_on = [aws_s3_object.host_config]
}
