# =============================================================================
# SonarQube on the dev host — storage
#
# The server itself is a container in docker-compose.yml.tftpl and its database
# is the SQL Server container that is already on this box, so the only AWS
# resource SonarQube needs is somewhere to put Elasticsearch's indices.
#
# Same shape as aws_ebs_volume.logging, for the same two reasons:
#   * user_data is immutable, so any change to the rendered config replaces the
#     instance — and the root volume goes with it. This one is not
#     delete_on_termination, so the analyses, the installed plugins and the
#     Elasticsearch indices survive the replacement;
#   * Elasticsearch's index writes do not share IOPS with SQL Server's data
#     files, which matters more than usual here because an analysis is a burst
#     of heavy I/O against a box that is also serving seven APIs.
#
# Nothing else in this file talks to AWS: no CodeBuild, no managed SonarQube, no
# S3 for the reports. CI reaches the server over HTTP(S) like any other scanner
# would (see run-sonar.sh and .github/workflows/terraform-pipeline.yml).
# =============================================================================

resource "aws_ebs_volume" "sonarqube" {
  count = var.sonarqube.enabled ? 1 : 0

  availability_zone = aws_subnet.public[0].availability_zone
  size              = var.sonarqube.volume_size_gb
  type              = "gp3"
  encrypted         = true

  tags = merge(local.tags, {
    Name    = "${local.name}-sonarqube-data"
    Purpose = "sonarqube-elasticsearch"
  })
}

resource "aws_volume_attachment" "sonarqube" {
  count = var.sonarqube.enabled ? 1 : 0

  device_name = var.sonarqube.volume_device
  volume_id   = aws_ebs_volume.sonarqube[0].id
  instance_id = aws_instance.app.id

  # Same reasoning as the logging attachment: a gp3 volume can usually be
  # detached from a running instance, but not reliably, and a stuck attachment
  # blocks the apply. The scheduler stops this box every evening anyway.
  stop_instance_before_detaching = true
}
