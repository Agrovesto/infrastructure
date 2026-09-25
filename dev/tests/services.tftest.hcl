# =============================================================================
# DEV — Redis and SonarQube on the app host
#
# Both are containers in the same compose project as everything else, so most of
# what is worth pinning is not an AWS resource at all: it is the rendered
# database bootstrap, the compose service and the nginx vhost. The AWS resources
# that do exist are one EBS volume and two SSM parameters, and both are here.
#
# Run with:  terraform -chdir=dev init && terraform -chdir=dev test
# =============================================================================

mock_provider "aws" {
  mock_resource "aws_ssm_parameter" {
    defaults = {
      version = 1
    }
  }
}

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
      env       = { REDIS_HOST = "redis", REDIS_PORT = "6379" }
    }
  }

  amplify_apps = {
    landing = {
      repository = "https://github.com/Agrovesto/nomaos-landingpage"
      branch     = "dev"
      subdomain  = "dev-agrovesto"
      framework  = "React"
    }
  }
}

# -----------------------------------------------------------------------------
# The SonarQube database: collation, snapshot isolation, and a scoped login
# -----------------------------------------------------------------------------

run "sonar_database_bootstrap" {
  command = plan

  assert {
    condition     = strcontains(local.init_sql, "CREATE DATABASE [sonar] COLLATE ${var.sonarqube.database_collation};")
    error_message = "The sonar database must be created with an explicit CS_AS collation; the SQL Server default is case-insensitive and SonarQube refuses to run on it."
  }

  assert {
    condition     = strcontains(local.init_sql, "SET READ_COMMITTED_SNAPSHOT ON")
    error_message = "READ_COMMITTED_SNAPSHOT must be enabled or analyses deadlock under load."
  }

  assert {
    condition     = strcontains(local.init_sql, "is_read_committed_snapshot_on")
    error_message = "The snapshot setting is guarded by a check, so re-running the bootstrap cannot roll back live SonarQube connections."
  }

  assert {
    condition     = strcontains(local.init_sql, "CREATE LOGIN [${var.sonarqube.database_username}]") && strcontains(local.init_sql, "ALTER ROLE db_owner ADD MEMBER")
    error_message = "SonarQube gets a login of its own, scoped to db_owner of the sonar database rather than sysadmin over the server."
  }

  assert {
    condition     = strcontains(local.init_sql, "$(sonar_db_password)") && !strcontains(local.init_sql, var.sonarqube.database_password)
    error_message = "The login password must arrive as a sqlcmd variable and never appear literally in init-dbs.sql, which is uploaded to S3."
  }

  assert {
    condition     = !strcontains(local.host_config_files["scripts/init-dbs.sql"].content, var.sonarqube.database_password)
    error_message = "The S3 object itself must be free of the password, not just the local it is rendered from."
  }
}

run "sonar_database_in_backup_set" {
  command = plan

  assert {
    condition     = contains(local.mssql_all_databases, var.sonarqube.database_name) && !contains(var.mssql_databases, var.sonarqube.database_name)
    error_message = "SonarQube's database is added to the created-and-backed-up set without having to be listed twice."
  }

  assert {
    condition     = length(local.mssql_all_databases) == length(var.mssql_databases) + 1
    error_message = "Exactly one database is added."
  }

  assert {
    condition     = contains(local.mssql_all_databases, "sonar") && strcontains(file("${path.module}/user_data.sh.tftpl"), "for db in $${db_list}; do")
    error_message = "The nightly backup loop iterates the same set the bootstrap creates."
  }
}

run "sonar_database_idempotent" {
  command = plan

  variables {
    mssql_databases = ["wallet", "onboarding", "input", "moneval", "serviceprovider", "sonar"]
  }

  assert {
    condition     = length(local.mssql_all_databases) == 6 && length(regexall("CREATE DATABASE \\[sonar\\]", local.init_sql)) == 1
    error_message = "Listing the sonar database in mssql_databases as well must not create it twice, or create it without the collation."
  }
}

# -----------------------------------------------------------------------------
# AWS resources: one volume, two parameters
# -----------------------------------------------------------------------------

run "sonarqube_storage" {
  command = plan

  assert {
    condition     = length(aws_ebs_volume.sonarqube) == 1 && length(aws_volume_attachment.sonarqube) == 1
    error_message = "SonarQube's Elasticsearch indices live on a volume of their own, not on the root disk."
  }

  assert {
    condition     = aws_ebs_volume.sonarqube[0].encrypted && aws_ebs_volume.sonarqube[0].type == "gp3"
    error_message = "The volume is encrypted gp3, like every other volume on this host."
  }

  assert {
    condition     = aws_ebs_volume.sonarqube[0].tags["Purpose"] == "sonarqube-elasticsearch"
    error_message = "The volume is tagged with what it holds."
  }

  assert {
    condition     = aws_volume_attachment.sonarqube[0].device_name == var.sonarqube.volume_device && aws_volume_attachment.sonarqube[0].stop_instance_before_detaching
    error_message = "The volume attaches at /dev/sdh — after mssql (/dev/sdf) and logging (/dev/sdg) — and detaches by stopping the host rather than risking a stuck attachment."
  }

  assert {
    condition     = length(distinct([var.mssql_volume_device, var.logging.volume_device, var.sonarqube.volume_device])) == 3
    error_message = "The three data volumes use three distinct device names."
  }
}

run "service_passwords" {
  command = plan

  assert {
    condition     = length(aws_ssm_parameter.sonarqube_db_password) == 1 && aws_ssm_parameter.sonarqube_db_password[0].type == "SecureString"
    error_message = "The SonarQube SQL password is a SecureString in SSM, fetched at boot rather than rendered into user data."
  }

  assert {
    condition     = aws_ssm_parameter.sonarqube_db_password[0].name == "/${local.name}/sonarqube_db_password"
    error_message = "SonarQube DB password parameter is placed under the stack prefix."
  }

  assert {
    condition     = aws_kms_key.host_passwords.enable_key_rotation == true
    error_message = "Host passwords KMS key has key rotation enabled."
  }

  assert {
    condition     = length(aws_ssm_parameter.redis_password) == 0
    error_message = "Redis has no password by default, so no parameter is created for one."
  }

  assert {
    condition     = length(local.host_password_param_arns) == 10
    error_message = "The instance role is scoped to the host password and SSO parameters: SA, Grafana, SonarQube, Redis, plus GitHub credentials for SonarQube and Grafana."
  }

  assert {
    condition     = alltrue([for arn in local.host_password_param_arns : strcontains(arn, "parameter/${local.name}/")])
    error_message = "Every parameter the role may read lives under this stack's own path prefix, so it cannot read another stack's secrets."
  }
}

run "redis_password_parameter" {
  command = plan

  variables {
    redis = { password = "Str0ng!RedisTestOnly" } # ggignore - test fixture, not a credential
  }

  assert {
    condition     = length(aws_ssm_parameter.redis_password) == 1 && aws_ssm_parameter.redis_password[0].type == "SecureString"
    error_message = "Setting a Redis password stores it in SSM rather than interpolating it into user data, which is readable from instance metadata."
  }

  assert {
    condition     = strcontains(local.docker_compose, "--requirepass") && !strcontains(local.docker_compose, "Str0ng!RedisTestOnly")
    error_message = "The compose file passes --requirepass by .env reference; the password itself must not be rendered into it."
  }
}

# -----------------------------------------------------------------------------
# compose: both services, loopback-only, capped
# -----------------------------------------------------------------------------

run "compose_services" {
  command = plan

  assert {
    condition     = strcontains(local.docker_compose, "container_name: agrovesto-redis") && strcontains(local.docker_compose, "container_name: agrovesto-sonarqube")
    error_message = "Both services are in the compose project, with the agrovesto- container name the collector derives its `service` label from."
  }

  assert {
    condition     = strcontains(local.docker_compose, "127.0.0.1:${var.redis.host_port}:6379") && strcontains(local.docker_compose, "127.0.0.1:${var.sonarqube.host_port}:9000")
    error_message = "Neither service publishes a non-loopback port; the security group still opens nothing for them."
  }

  assert {
    condition     = strcontains(local.docker_compose, "--maxmemory ${var.redis.maxmemory_mb}mb") && strcontains(local.docker_compose, "--maxmemory-policy ${var.redis.maxmemory_policy}")
    error_message = "Redis is bounded and has an eviction policy: SQL Server shares this box, so a cache that grows without bound is what takes the APIs down."
  }

  assert {
    condition     = strcontains(local.docker_compose, "SONAR_JDBC_URL: \"${local.sonar_jdbc_url}\"")
    error_message = "SonarQube points at the on-host SQL Server over the compose network."
  }

  assert {
    condition     = strcontains(local.sonar_jdbc_url, "jdbc:sqlserver://mssql:1433") && !strcontains(local.sonar_jdbc_url, "127.0.0.1") && !strcontains(local.sonar_jdbc_url, "localhost")
    error_message = "SonarQube must reach SQL Server by compose-network service name, not through the loopback host publish."
  }

  assert {
    condition     = strcontains(local.sonar_jdbc_url, "trustServerCertificate=true")
    error_message = "The SQL Server container presents a self-signed certificate, so the JDBC driver has to be told to trust it or it refuses the connection."
  }

  assert {
    condition     = strcontains(local.docker_compose, "SONAR_JDBC_PASSWORD: \"$${SONAR_DB_PASSWORD}\"") && !strcontains(local.docker_compose, var.sonarqube.database_password)
    error_message = "The password is referenced from compose .env as $$VAR and never written into the compose file, which is an S3 object."
  }

  assert {
    condition     = strcontains(local.docker_compose, "mem_limit: ${var.redis.memory_limit_mb}M") && strcontains(local.docker_compose, "mem_limit: ${var.sonarqube.memory_limit_mb}M")
    error_message = "Both carry a memory cap. SonarQube's is the one that matters: it makes the cgroup kill SonarQube instead of the kernel OOM-killing SQL Server."
  }

  assert {
    condition     = strcontains(local.docker_compose, "SONAR_ES_JAVA_OPTS: \"${var.sonarqube.es_java_opts}\"")
    error_message = "The Elasticsearch heap is set explicitly rather than left to SonarQube's default, which assumes a box with RAM to spare."
  }

  assert {
    condition     = strcontains(local.docker_compose, "SONAR_WEB_BASEURL: \"${local.sonar_web_baseurl}\"") && local.sonar_web_baseurl == "${var.sonarqube.scheme}://sonar.${var.domain_name}"
    error_message = "SonarQube knows its own public URL, which it needs for absolute links and for validating OAuth redirects."
  }

  assert {
    condition     = strcontains(local.docker_compose, "REDIS_HOST: \"redis\"")
    error_message = "The APIs are told where Redis is by compose-network name."
  }
}

run "compose_persistence" {
  command = plan

  variables {
    redis = { persistence = true }
  }

  assert {
    condition     = strcontains(local.docker_compose, "--appendonly yes") && strcontains(local.docker_compose, "${var.redis.data_dir}:/data")
    error_message = "Turning persistence on enables the AOF and mounts the data directory."
  }
}

# -----------------------------------------------------------------------------
# nginx: the sonar vhost, IP-gated like Grafana's
# -----------------------------------------------------------------------------

run "nginx_vhost" {
  command = plan

  variables {
    sonarqube = { allowed_cidrs = [] }
  }

  assert {
    condition     = strcontains(local.nginx_conf, "server_name sonar.nomaos.com;")
    error_message = "nginx serves the SonarQube vhost on the subdomain the DNS record points at."
  }

  assert {
    condition     = strcontains(local.nginx_conf, "proxy_pass http://sonarqube:${local.sonarqube_nginx.port};")
    error_message = "The vhost proxies to the container port on the compose network, not to the published host port."
  }

  assert {
    condition     = strcontains(local.nginx_conf, "allow 127.0.0.1;") && strcontains(local.nginx_conf, "deny all;")
    error_message = "An empty allow list is not 'everyone': the vhost falls back to 127.0.0.1, i.e. SSH-tunnel-only."
  }

  assert {
    condition     = strcontains(local.nginx_conf, "client_max_body_size 100m;")
    error_message = "The vhost accepts analysis report uploads, which are far larger than nginx's 1m default."
  }

  assert {
    condition     = strcontains(local.nginx_conf, "proxy_read_timeout 600s;")
    error_message = "Report computation takes minutes; the default 60s would cut it off mid-analysis."
  }

  assert {
    condition     = strcontains(local.docker_compose, "      - sonarqube\n")
    error_message = "nginx depends_on sonarqube: nginx resolves a static proxy_pass hostname at start-up, so an absent container fails nginx instead of 502ing."
  }
}

run "github_sso_uses_https_and_ssm_credentials" {
  command = plan

  variables {
    sonarqube = {
      allowed_cidrs = ["203.0.113.10/32"]
    }
    logging = {
      allowed_cidrs = ["203.0.113.10/32"]
    }
    sonarqube_github_client_id     = "test-sonarqube-client-id"
    sonarqube_github_client_secret = "not-a-real-sonarqube-secret" # ggignore - test fixture
    sonarqube_github_app_id        = "123456"
    sonarqube_github_private_key   = "test-private-key-material" # ggignore - test fixture
    grafana_github_client_id       = "test-grafana-client-id"
    grafana_github_client_secret   = "not-a-real-grafana-secret" # ggignore - test fixture
  }

  assert {
    condition = alltrue([
      length(aws_ssm_parameter.sonarqube_github_client_id) == 1,
      length(aws_ssm_parameter.sonarqube_github_client_secret) == 1,
      length(aws_ssm_parameter.sonarqube_github_app_id) == 1,
      length(aws_ssm_parameter.sonarqube_github_private_key) == 1,
      length(aws_ssm_parameter.grafana_github_client_id) == 1,
      length(aws_ssm_parameter.grafana_github_client_secret) == 1,
    ])
    error_message = "Both identity providers must put every credential in an SSM SecureString."
  }

  assert {
    condition = alltrue([
      local.sonar_web_baseurl == "https://sonar.nomaos.com",
      local.logging_runtime.grafana_root_url == "https://dev-logs.nomaos.com",
      strcontains(local.caddyfile, "sonar.nomaos.com"),
      strcontains(local.caddyfile, "dev-logs.nomaos.com"),
      strcontains(local.docker_compose, "container_name: agrovesto-edge"),
      strcontains(local.docker_compose, "80:80"),
      strcontains(local.docker_compose, "443:443"),
    ])
    error_message = "GitHub callbacks must use the Caddy-managed HTTPS edge for both dev UIs."
  }

  assert {
    condition = alltrue([
      strcontains(local.docker_compose, "GF_AUTH_GITHUB_ENABLED"),
      strcontains(local.docker_compose, "GF_AUTH_GITHUB_CLIENT_SECRET: \"$${GRAFANA_GITHUB_CLIENT_SECRET}\""),
      strcontains(local.docker_compose, "sonar-sso.properties:/opt/sonarqube/conf/sonar.properties:ro"),
      strcontains(file("${path.module}/user_data.sh.tftpl"), "sonar.auth.github.clientSecret.secured"),
      strcontains(file("${path.module}/user_data.sh.tftpl"), "sonar.auth.github.organizations"),
      strcontains(file("${path.module}/user_data.sh.tftpl"), "sonar.auth.github.groupsSync"),
    ])
    error_message = "Grafana and SonarQube must receive their supported GitHub authentication and group-sync settings."
  }

  assert {
    condition = alltrue([
      strcontains(local.docker_compose, "GF_AUTH_GITHUB_ROLE_ATTRIBUTE_PATH"),
      strcontains(local.docker_compose, "@Agrovesto/infrastructure') && 'Admin'"),
      strcontains(local.docker_compose, "@Agrovesto/team-leads') && 'Editor'"),
      strcontains(local.docker_compose, "@Agrovesto/backend') && 'Viewer'"),
      strcontains(local.docker_compose, "@Agrovesto/frontend') && 'Viewer'"),
      strcontains(local.docker_compose, "@Agrovesto/mobile') && 'Viewer'"),
      strcontains(local.docker_compose, "GF_AUTH_GITHUB_ROLE_ATTRIBUTE_STRICT: \"true\""),
      strcontains(local.docker_compose, "GF_AUTH_GITHUB_ALLOW_ASSIGN_GRAFANA_ADMIN: \"false\""),
    ])
    error_message = "Dev Grafana must assign the requested team roles, reject unlisted teams, and keep Admin below server-admin scope."
  }

  assert {
    condition = alltrue([
      !strcontains(local.docker_compose, "not-a-real-grafana-secret"),
      !strcontains(local.docker_compose, "not-a-real-sonarqube-secret"),
      !strcontains(file("${path.module}/user_data.sh.tftpl"), "not-a-real-grafana-secret"),
      !strcontains(file("${path.module}/user_data.sh.tftpl"), "not-a-real-sonarqube-secret"),
      !strcontains(local.caddyfile, "not-a-real"),
    ])
    error_message = "OAuth secrets must never enter compose, Caddy config, S3 host config, or EC2 user_data."
  }

  assert {
    condition = (
      length(aws_s3_object.host_config) == 14 &&
      aws_s3_object.host_config["edge/Caddyfile"].content == local.caddyfile &&
      aws_s3_object.host_config["scripts/configure-sonarqube-team-permissions.sh"].content == file("${path.module}/configure-sonarqube-team-permissions.sh")
    )
    error_message = "SSO must ship the non-secret Caddy config and idempotent SonarQube team-role bootstrap script."
  }

  assert {
    condition = alltrue([
      strcontains(aws_s3_object.host_config["scripts/configure-sonarqube-team-permissions.sh"].content, "Agrovesto/Infrastructure"),
      strcontains(aws_s3_object.host_config["scripts/configure-sonarqube-team-permissions.sh"].content, "permission=admin"),
      strcontains(aws_s3_object.host_config["scripts/configure-sonarqube-team-permissions.sh"].content, "issueadmin securityhotspotadmin"),
      strcontains(aws_s3_object.host_config["scripts/configure-sonarqube-team-permissions.sh"].content, "user codeviewer"),
    ])
    error_message = "The SonarQube bootstrap must encode Admin, read/write, and reader permissions for the synchronized teams."
  }

  assert {
    condition = alltrue([
      strcontains(local.nginx_conf, "real_ip_header X-Forwarded-For"),
      strcontains(local.nginx_conf, "geo $realip_remote_addr $trusted_reverse_proxy"),
      strcontains(local.nginx_conf, "X-Forwarded-Proto $forwarded_proto"),
      aws_instance.app.user_data_replace_on_change,
      strcontains(file("${path.module}/user_data.sh.tftpl"), "sso_credential_versions"),
    ])
    error_message = "nginx must trust forwarded client data only from Caddy, and SSM credential rotation must replace the host."
  }
}

run "dns_record" {
  command = plan

  assert {
    condition     = contains(keys(local.a_records), var.sonarqube.subdomain)
    error_message = "The subdomain gets an A record at the host's Elastic IP — created here only when var.manage_dns is true, otherwise it is the prod zone's job."
  }

  assert {
    condition     = local.sonar_fqdn == "sonar.nomaos.com"
    error_message = "The FQDN is the one SONAR_HOST_URL and the DNS record must agree on."
  }
}

# -----------------------------------------------------------------------------
# Host bootstrap: the kernel limits Elasticsearch will not start without
# -----------------------------------------------------------------------------

run "host_bootstrap" {
  command = plan

  assert {
    condition     = strcontains(file("${path.module}/user_data.sh.tftpl"), "vm.max_map_count = $${sonarqube.vm_max_map_count}")
    error_message = "Elasticsearch fails a hard bootstrap check below 262144 mapped areas; Ubuntu's default is 65530."
  }

  assert {
    condition     = strcontains(file("${path.module}/user_data.sh.tftpl"), "/etc/sysctl.d/99-agrovesto-sonarqube.conf") && strcontains(file("${path.module}/user_data.sh.tftpl"), "sysctl --system")
    error_message = "The limit is persisted to /etc/sysctl.d and applied immediately, so it survives a reboot and works on the first boot."
  }

  assert {
    condition     = strcontains(file("${path.module}/user_data.sh.tftpl"), "format_and_mount \"$${sonarqube.data_dir}\"")
    error_message = "The volume is mounted at the configured data directory."
  }

  assert {
    condition     = strcontains(file("${path.module}/user_data.sh.tftpl"), "-v sonar_db_password=")
    error_message = "The bootstrap passes the login password to sqlcmd as a variable rather than baking it into the script."
  }

  assert {
    condition     = strcontains(file("${path.module}/user_data.sh.tftpl"), "SONAR_DB_PASSWORD=%s") && strcontains(file("${path.module}/user_data.sh.tftpl"), "unset SONAR_DB_PASSWORD")
    error_message = "The password goes into compose/.env from SSM and is unset from the boot script's environment afterwards."
  }
}

# -----------------------------------------------------------------------------
# Both services are optional: disabling them removes every trace
# -----------------------------------------------------------------------------

run "disabled" {
  command = plan

  variables {
    sonarqube = { enabled = false }
    redis     = { enabled = false }
  }

  assert {
    condition     = length(aws_ebs_volume.sonarqube) == 0 && length(aws_volume_attachment.sonarqube) == 0 && length(aws_ssm_parameter.sonarqube_db_password) == 0
    error_message = "With SonarQube off there is no volume, no attachment and no password parameter."
  }

  assert {
    condition = (
      !strcontains(local.docker_compose, "agrovesto-sonarqube") &&
      !strcontains(local.docker_compose, "agrovesto-redis") &&
      !strcontains(local.nginx_conf, "server_name sonar.")
    )
    error_message = "Neither container nor the vhost is rendered when the services are off."
  }

  assert {
    condition     = !strcontains(local.init_sql, "COLLATE") && !contains(local.mssql_all_databases, "sonar") && length(local.mssql_all_databases) == 5
    error_message = "Disabling SonarQube removes its database from the bootstrap; the five application databases are untouched."
  }

  assert {
    condition     = length(regexall("mem_limit:", local.docker_compose)) == 7
    error_message = "Only the seven observability containers remain capped."
  }
}

# -----------------------------------------------------------------------------
# OAuth credentials are atomic: an incomplete set must never silently deploy
# -----------------------------------------------------------------------------

run "rejects_partial_sonarqube_github_credentials" {
  command = plan

  variables {
    sonarqube_github_client_id = "github-client-id-without-the-other-fields"
  }

  expect_failures = [aws_instance.app]
}

run "rejects_partial_grafana_github_credentials" {
  command = plan

  variables {
    grafana_github_client_secret = "github-client-secret-without-an-id"
  }

  expect_failures = [aws_instance.app]
}