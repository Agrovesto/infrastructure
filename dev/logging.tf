# =============================================================================
# On-host logging stack — storage and config delivery
#
# Two things, both small, both deliberately not AWS "logging services":
#
#   1. an EBS volume that holds Loki's chunks, Prometheus' TSDB and Grafana's
#      data directory;
#   2. an S3 bucket that holds the rendered config files, which the host syncs
#      down in cloud-init.
#
# The observability components themselves are containers in
# docker-compose.yml.tftpl; nothing here sends, stores or reads logs in CloudWatch
# (or any other AWS log pipeline). The bucket is a file drop, exactly like
# monitoring/config.tf in the prod account — the alternative (heredocs in
# user_data) collides with the instance user-data size limit once the Grafana
# dashboards are in there, and it would show secrets in instance metadata.
# =============================================================================

# -----------------------------------------------------------------------------
# Log storage volume
#
# Its own volume rather than a directory on the root disk:
#   * user_data is immutable, so any config change here replaces the instance —
#     and the root volume goes with it. This one is not
#     delete_on_termination, so the logs, the TSDB and Grafana's sqlite survive
#     the replacement (the same trick the MSSQL data volume uses);
#   * Loki's compaction and SQL Server's data files do not share IOPS.
# -----------------------------------------------------------------------------

resource "aws_ebs_volume" "logging" {
  count = var.logging.enabled ? 1 : 0

  availability_zone = aws_instance.app.availability_zone
  size              = var.logging.volume_size_gb
  type              = "gp3"
  encrypted         = true

  tags = merge(local.tags, {
    Name    = "${local.name}-logging-data"
    Purpose = "loki-prometheus-grafana"
  })
}

resource "aws_volume_attachment" "logging" {
  count = var.logging.enabled ? 1 : 0

  device_name = var.logging.volume_device
  volume_id   = aws_ebs_volume.logging[0].id
  instance_id = aws_instance.app.id

  # A gp3 volume can be detached from a running instance most of the time, but
  # it is not guaranteed; letting AWS stop the host beats a stuck attachment
  # that blocks the apply. The scheduler stops the box every evening anyway.
  stop_instance_before_detaching = true

  tags = merge(local.tags, { Name = "${local.name}-logging-data" })
}
