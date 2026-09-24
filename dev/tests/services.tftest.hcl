# =============================================================================
# DEV — Redis and SonarQube on the app host
#
# Both are containers in the same compose project as everything else, so most of
# what is worth pinning is not an AWS resource at all: it is the rendered
# database bootstrap, the compose service and the nginx vhost. The AWS resources
# that do exist are one EBS volume and two SSM parameters, and both are here.
#
# The two things this suite exists to catch:
#
#   1. the `sonar` database being created with the server's default collation.
#      SonarSource requires case- AND accent-sensitive (CS_AS) plus
#      READ_COMMITTED_SNAPSHOT, and neither can be fixed after data exists — a
#      wrong collation means rebuilding the database and losing every analysis.
#
#   2. the SonarQube SQL login password ending up in scripts/init-dbs.sql. That
#      file is an object in the host config bucket, so a literal password there
#      is a secret in S3 and in the Terraform state's object content. It has to
#      travel as a sqlcmd variable instead.
#
# Run with:  terraform -chdir=dev init && terraform -chdir=dev test
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
    # The whole reason the password is a sqlcmd variable: init-dbs.sql is an
    # object in the host config bucket, so a literal here is a secret in S3.
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
    # var.mssql_databases does not list `sonar`; the union in locals adds it, so
    # the database that gets created is also the one that gets backed up.
    condition     = contains(local.mssql_all_databases, var.sonarqube.database_name) && !contains(var.mssql_databases, var.sonarqube.database_name)
    error_message = "SonarQube's database is added to the created-and-backed-up set without having to be listed twice."
  }

  assert {
    condition     = length(local.mssql_all_databases) == length(var.mssql_databases) + 1
    error_message = "Exactly one database is added."
  }

  assert {
    condition     = strcontains(aws_instance.app.user_data, "sonar") && strcontains(aws_instance.app.user_data, "for db in ${join(" ", local.mssql_all_databases)}")
    error_message = "The nightly backup loop iterates the same set the bootstrap creates."
  }
}

run "sonar_database_idempotent" {
  command = plan

  variables {
    mssql_databases = ["wallet", "onboarding", "input", "moneval", "serviceprovider", "sonar"]
  }

  assert {
    # Listed in both places on purpose: the union is deduplicated, and `sonar`
    # must still take the collated branch rather than the plain CREATE.
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
    # /dev/sdf, /dev/sdg and /dev/sdh must not collide: user_data mounts each by
    # NVMe id, and two volumes claiming one device name is an unmountable boot.
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
    condition     = aws_ssm_parameter.sonarqube_db_password[0].key_id == aws_kms_key.host_passwords.arn
    error_message = "It is encrypted with the stack's own customer-managed key, like the other host passwords."
  }

  assert {
    # No AUTH by default: the port is loopback-only and the compose network is
    # private to the host, so there is no parameter to create yet.
    condition     = length(aws_ssm_parameter.redis_password) == 0
    error_message = "Redis has no password by default, so no parameter is created for one."
  }

  assert {
    condition     = length(local.host_password_param_arns) == 4
    error_message = "The instance role is scoped to exactly the four password parameters the host reads at boot: SA, Grafana, SonarQube and Redis."
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
    # The intent is "over the compose network, by service name" rather than
    # "not the host publish port" — the two are the same number (1433) by
    # default, so asserting on the port alone would prove nothing.
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

  assert {
    condition     = strcontains(local.nginx_conf, "server_name sonar.nomaos.com;")
    error_message = "nginx serves the SonarQube vhost on the subdomain the DNS record points at."
  }

  assert {
    condition     = strcontains(local.nginx_conf, "proxy_pass http://sonarqube:${local.sonarqube_nginx.port};")
    error_message = "The vhost proxies to the container port on the compose network, not to the published host port."
  }

  assert {
    condition     = strcontains(local.nginx_conf, "deny all;") && local.sonarqube_nginx.cidrs == ["127.0.0.1"]
    error_message = "An empty allow list is not 'everyone': the vhost falls back to 127.0.0.1, i.e. SSH-tunnel-only."
  }

  assert {
    # A report upload is a multi-megabyte POST; the 1m default would reject it
    # with a 413 that the scanner surfaces as an opaque failure.
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

run "dns_record" {
  command = plan

  assert {
    condition     = contains(keys(local.a_records), var.sonarqube.subdomain) && local.a_records[var.sonarqube.subdomain] == local.ec2_public_ip
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
    condition     = strcontains(aws_instance.app.user_data, "vm.max_map_count = ${var.sonarqube.vm_max_map_count}")
    error_message = "Elasticsearch fails a hard bootstrap check below 262144 mapped areas; Ubuntu's default is 65530."
  }

  assert {
    condition     = strcontains(aws_instance.app.user_data, "/etc/sysctl.d/99-agrovesto-sonarqube.conf") && strcontains(aws_instance.app.user_data, "sysctl --system")
    error_message = "The limit is persisted to /etc/sysctl.d and applied immediately, so it survives a reboot and works on the first boot."
  }

  assert {
    condition     = strcontains(aws_instance.app.user_data, "format_and_mount \"${var.sonarqube.data_dir}\"") && strcontains(aws_instance.app.user_data, "chown -R 1000:1000")
    error_message = "The volume is mounted and handed to uid 1000, which is what the sonarqube image runs as — Elasticsearch refuses to run as root."
  }

  assert {
    condition     = strcontains(aws_instance.app.user_data, "-v sonar_db_password=")
    error_message = "The bootstrap passes the login password to sqlcmd as a variable rather than baking it into the script."
  }

  assert {
    condition     = strcontains(aws_instance.app.user_data, "SONAR_DB_PASSWORD=%s") && strcontains(aws_instance.app.user_data, "unset SA_PW GRAFANA_PW SONAR_DB_PW REDIS_PW")
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
    # The sonar database must not be created either, and the other five must be.
    condition     = !strcontains(local.init_sql, "COLLATE") && !contains(local.mssql_all_databases, "sonar") && length(local.mssql_all_databases) == 5
    error_message = "Disabling SonarQube removes its database from the bootstrap; the five application databases are untouched."
  }

  assert {
    condition     = !strcontains(aws_instance.app.user_data, "vm.max_map_count")
    error_message = "The host-wide kernel tuning is only applied when something needs it."
  }

  assert {
    condition     = length(regexall("mem_limit:", local.docker_compose)) == 7
    error_message = "Only the seven observability containers remain capped."
  }
}
