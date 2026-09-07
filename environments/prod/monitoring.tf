resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = local.name
  dashboard_body = jsonencode({ widgets = [
    { type = "text", x = 0, y = 0, width = 24, height = 2, properties = { markdown = "# ${local.name}\nPrivate ECS services across two AZs; single-AZ RDS SQL Server Standard; TLS ALB (no WAF); alarms. All times UTC." } },
    { type = "metric", x = 0, y = 2, width = 12, height = 6, properties = {
      region  = var.aws_region, title = "RDS CPU", period = 300, stat = "Average"
      metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", module.database.identifier]]
    } },
    { type = "metric", x = 12, y = 2, width = 12, height = 6, properties = {
      region  = var.aws_region, title = "RDS free disk / memory (bytes)", period = 300, stat = "Minimum"
      metrics = [["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", module.database.identifier], ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", module.database.identifier]]
    } },
    { type = "metric", x = 0, y = 8, width = 12, height = 6, properties = {
      region  = var.aws_region, title = "API requests / 5xx", period = 300, stat = "Sum"
      metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.edge.arn_suffix], ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", module.edge.arn_suffix]]
    } },
    { type = "metric", x = 12, y = 8, width = 12, height = 6, properties = {
      region  = var.aws_region, title = "ECS service CPU", period = 300, stat = "Average"
      metrics = [for name in keys(var.services) : ["AWS/ECS", "CPUUtilization", "ClusterName", module.services.cluster_name, "ServiceName", name]]
    } }
  ] })
}
