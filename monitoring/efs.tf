# One Zone storage keeps the stack cheap; every task is pinned to the subnet in
# the same AZ so the single mount target is reachable.

resource "aws_efs_file_system" "monitoring" {
  creation_token         = local.name
  encrypted              = true
  kms_key_id             = aws_kms_key.monitoring.arn
  availability_zone_name = data.aws_subnet.monitoring.availability_zone
  throughput_mode        = "elastic"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = merge(local.tags, { Name = local.name })
}

resource "aws_efs_mount_target" "monitoring" {
  file_system_id  = aws_efs_file_system.monitoring.id
  subnet_id       = local.monitor_subnet_id
  security_groups = [aws_security_group.efs.id]
}

# Configuration and data directory per component. The uid/gid matches the user
# each upstream image runs as, so the containers can write their own data.

locals {
  efs_access_points = {
    prometheus   = 65534
    alertmanager = 65534
    loki         = 10001
    tempo        = 10001
    grafana      = 472
    alloy        = 0
    blackbox     = 65534
    rds          = 0
  }
}

resource "aws_efs_access_point" "monitoring" {
  for_each = local.efs_access_points

  file_system_id = aws_efs_file_system.monitoring.id

  posix_user {
    uid = each.value
    gid = each.value
  }

  root_directory {
    path = "/${each.key}"

    creation_info {
      owner_uid   = each.value
      owner_gid   = each.value
      permissions = "0755"
    }
  }

  tags = merge(local.tags, { Name = "${local.name}-${each.key}" })
}
