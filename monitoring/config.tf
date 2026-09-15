# Configuration delivery.
#
# Every component reads its config from its EFS volume: the values below are
# published to SSM Parameter Store and a small aws-cli init container materialises
# them into <mount>/config inside the task, so no custom images are needed.
#
#   SSM: /<name>/<component>/<relative path>  ->  <mount>/config/<relative path>
#
# Changing a value here needs a service redeploy to take effect
# (aws ecs update-service --force-new-deployment).

locals {
  base_config_parameters = {
    "prometheus/prometheus.yml"                        = local.prometheus_config
    "prometheus/rules/platform.yml"                    = local.prometheus_platform_rules
    "prometheus/rules/cost.yml"                        = local.prometheus_cost_rules
    "alertmanager/alertmanager.yml"                    = local.alertmanager_config
    "loki/config.yml"                                  = local.loki_config
    "loki/rules/application.yml"                       = local.loki_rules
    "tempo/config.yml"                                 = local.tempo_config
    "alloy/config.alloy"                               = local.alloy_config
    "blackbox/blackbox.yml"                            = local.blackbox_config
    "grafana/provisioning/datasources/datasources.yml" = local.grafana_datasources
    "grafana/provisioning/dashboards/dashboards.yml"   = local.grafana_dashboards_provider
    "grafana/dashboards/platform.json"                 = file("${path.module}/dashboards/platform.json")
    "grafana/dashboards/services.json"                 = file("${path.module}/dashboards/services.json")
    "grafana/dashboards/cost.json"                     = file("${path.module}/dashboards/cost.json")
  }

  rds_config_parameters = local.mssql_enabled ? {
    "rds/mssql_metrics.py"          = file("${path.module}/scripts/mssql_metrics.py")
    "prometheus/rules/database.yml" = local.prometheus_rds_rules
  } : {}

  config_parameters = merge(local.base_config_parameters, local.rds_config_parameters)
}

resource "aws_ssm_parameter" "config" {
  for_each = local.config_parameters

  name       = "${local.param}/${each.key}"
  type       = "SecureString"
  value      = each.value
  key_id     = "alias/${local.name}-efs"

  tags = local.tags
}

# Generated once and kept in SSM; the container only ever sees it as an
# injected secret (no cleartext in the task definition or in tfvars).
resource "random_password" "grafana_admin" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "grafana_admin_password" {
  name       = "${local.param}/grafana/admin-password"
  type       = "SecureString"
  value      = random_password.grafana_admin.result
  key_id     = "alias/${local.name}-efs"

  tags = local.tags
}
