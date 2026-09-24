# =============================================================================
# One-shot import blocks: adopt the existing AWS resources into this stack's
# state (see docs/import-runbook.md). After the first clean apply they are
# no-ops; delete this file once `terraform plan` shows "No changes".
# =============================================================================

import {
  to = aws_cloudwatch_log_group.legacy_ec2_auth
  id = "ec2-auth"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:ec2-cloud-init
import {
  to = aws_cloudwatch_log_group.legacy_ec2_cloud_init
  id = "ec2-cloud-init"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:ec2-cloud-init-output
import {
  to = aws_cloudwatch_log_group.legacy_ec2_cloud_init_output
  id = "ec2-cloud-init-output"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:ec2-kernel
import {
  to = aws_cloudwatch_log_group.legacy_ec2_kernel
  id = "ec2-kernel"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:ec2-syslog
import {
  to = aws_cloudwatch_log_group.legacy_ec2_syslog
  id = "ec2-syslog"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:nginx-access
import {
  to = aws_cloudwatch_log_group.legacy_nginx_access
  id = "nginx-access"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:nginx-error
import {
  to = aws_cloudwatch_log_group.legacy_nginx_error
  id = "nginx-error"
}

# arn:aws:logs:eu-west-1:221434544570:log-group:RDSOSMetrics
import {
  to = aws_cloudwatch_log_group.legacy_rdsosmetrics
  id = "RDSOSMetrics"
}


# --- aws_ssm_association ---------------------------------------------------
# arn:aws:ssm:eu-west-1:221434544570:association/ef34e30b-8367-4e4e-96d6-573010af70ef
import {
  to = aws_ssm_association.legacy_assoc_ef34e30b
  id = "ef34e30b-8367-4e4e-96d6-573010af70ef"
}


# --- aws_ssm_parameter -----------------------------------------------------
# arn:aws:ssm:eu-west-1:221434544570:parameter/AmazonCloudWatch-linux
# NOTE: value enters state; for SecureString params prefer an ephemeral/data read
import {
  to = aws_ssm_parameter.legacy_amazoncloudwatch_linux
  id = "AmazonCloudWatch-linux"
}
