resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = local.name
  dashboard_body = jsonencode({ widgets = [
    { type = "text", x = 0, y = 0, width = 24, height = 2, properties = { markdown = "# ${local.name}\nSingle-host dev: check SQL native backup heartbeat, both disks and ALB health. All times UTC." } },
    { type = "metric", x = 0, y = 2, width = 12, height = 6, properties = {
      region  = var.aws_region, title = "Host CPU / memory", period = 300, stat = "Average"
      metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", module.host.instance_id], ["${var.project}/System", "mem_used_percent", "InstanceId", module.host.instance_id]]
    } },
    { type = "metric", x = 12, y = 2, width = 12, height = 6, properties = {
      region  = var.aws_region, title = "OS and SQL disk used %", period = 300, stat = "Maximum"
      metrics = [["${var.project}/System", "disk_used_percent", "InstanceId", module.host.instance_id, "path", "/"], ["${var.project}/System", "disk_used_percent", "InstanceId", module.host.instance_id, "path", "/srv/mssql"]]
    } },
    { type = "metric", x = 0, y = 8, width = 12, height = 6, properties = {
      region  = var.aws_region, title = "SQL S3 backup heartbeat", period = 86400, stat = "Minimum"
      metrics = [["${var.project}/Backups", "DatabaseBackupSuccess", "Environment", "dev"]]
    } },
    { type = "metric", x = 12, y = 8, width = 12, height = 6, properties = {
      region  = var.aws_region, title = "API requests / 5xx", period = 300, stat = "Sum"
      metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.edge.arn_suffix], ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", module.edge.arn_suffix]]
    } }
  ] })
}
