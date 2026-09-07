locals {
  logging = {
    driver = "awslogs"
    options = {
      awslogs-region       = var.region, awslogs-group = aws_cloudwatch_log_group.containers.name
      awslogs-create-group = "false", tag = "{{.Name}}"
    }
  }
  compose = yamlencode({
    name = var.name
    services = merge({
      mssql = {
        image          = var.sqlserver_image
        container_name = "${var.name}-mssql"
        restart        = "unless-stopped"
        user           = "10001:0"
        mem_limit      = "5g"
        environment    = { ACCEPT_EULA = "Y", MSSQL_PID = "Developer", MSSQL_MEMORY_LIMIT_MB = "4096" }
        env_file       = [{ path = "/run/agrovesto/sql.env", format = "raw" }]
        volumes        = ["/srv/mssql:/var/opt/mssql"]
        # No ports mapping: TCP 1433 is reachable only on the Docker bridge.
        security_opt      = ["no-new-privileges:true"]
        cap_drop          = ["ALL"]
        logging           = local.logging
        stop_grace_period = "90s"
        healthcheck = {
          test     = ["CMD-SHELL", "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -N -C -b -Q 'SELECT 1' >/dev/null 2>&1"]
          interval = "30s", timeout = "10s", retries = 5, start_period = "60s"
        }
      }
      }, { for name, s in local.active_services : name => {
        image        = s.image
        restart      = "unless-stopped"
        ports        = ["${s.host_port}:${s.port}"]
        user         = s.user
        read_only    = true
        tmpfs        = ["/tmp:rw,noexec,nosuid,size=64m,mode=1777"]
        mem_limit    = "${s.memory_mb}m"
        environment  = s.environment
        env_file     = [{ path = "/run/agrovesto/${name}.env", format = "raw" }]
        cap_drop     = ["ALL"]
        security_opt = ["no-new-privileges:true"]
        logging      = local.logging
    } })
  })
  runtime_config = jsonencode({
    environment      = "dev", project = var.project, region = var.region
    volume_id        = aws_ebs_volume.database.id, volume_size = var.database_volume_size
    db_host          = "mssql", sql_container = "${var.name}-mssql"
    admin_secret_arn = aws_secretsmanager_secret.admin.arn
    backup_bucket    = module.backups.id, kms_key_arn = var.kms_key_arn
    data_mount       = "/srv/mssql", env_dir = "/run/agrovesto"
    databases        = { for key, name in var.databases : key => { name = name, secret_arn = var.database_secret_arns[key] } }
    services         = local.active_services
    image_registries = distinct([for s in values(local.active_services) : split("/", s.image)[0]])
  })
  cloudwatch_config = jsonencode({
    agent = { metrics_collection_interval = 60, run_as_user = "root" }
    metrics = {
      namespace              = "${var.project}/System"
      append_dimensions      = { InstanceId = "$${aws:InstanceId}" }
      aggregation_dimensions = [["InstanceId"], ["InstanceId", "path"]]
      metrics_collected = {
        mem  = { measurement = ["mem_used_percent"] }
        disk = { measurement = ["used_percent"], resources = ["/", "/srv/mssql"], drop_device = true }
      }
    }
    logs = { logs_collected = { files = { collect_list = [
      { file_path = "/var/log/cloud-init-output.log", log_group_name = aws_cloudwatch_log_group.host.name, log_stream_name = "{instance_id}/bootstrap" },
      { file_path = "/var/log/messages", log_group_name = aws_cloudwatch_log_group.host.name, log_stream_name = "{instance_id}/system" }
    ] } } }
  })
  files = {
    "compose.yaml"             = local.compose
    "runtime.json"             = local.runtime_config
    "cloudwatch.json"          = local.cloudwatch_config
    "database.py"              = file("${path.module}/../../scripts/database.py")
    "requirements.txt"         = file("${path.module}/../../ops/sql-admin/requirements.txt")
    "install.sh"               = file("${path.module}/../../scripts/dev/install.sh")
    "start.sh"                 = file("${path.module}/../../scripts/dev/start.sh")
    "agrovesto.service"        = file("${path.module}/../../scripts/dev/agrovesto.service")
    "agrovesto-backup.service" = file("${path.module}/../../scripts/dev/agrovesto-backup.service")
    "agrovesto-backup.timer"   = file("${path.module}/../../scripts/dev/agrovesto-backup.timer")
  }
  release_hash = sha256(jsonencode(local.files))
}
resource "aws_s3_object" "release" {
  for_each               = local.files
  bucket                 = module.artifacts.id
  key                    = "releases/${local.release_hash}/${each.key}"
  content                = each.value
  source_hash            = sha256(each.value)
  server_side_encryption = "aws:kms"
  kms_key_id             = var.kms_key_arn
  # Old keys may be removed from live S3 on updates; versioning preserves recovery.
}
