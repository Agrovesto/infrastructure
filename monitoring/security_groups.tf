resource "aws_security_group" "internal" {
  name        = "${local.name}-internal-sg"
  description = "Monitoring components: scrape, ingest and query ports from inside the VPC"
  vpc_id      = data.aws_vpc.prod.id

  tags = merge(local.tags, { Name = "${local.name}-internal" })
}

resource "aws_security_group_rule" "internal_prometheus" {
  type              = "ingress"
  security_group_id = aws_security_group.internal.id
  description       = "Prometheus UI/API and remote write"
  from_port         = 9090
  to_port           = 9090
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.prod.cidr_block]
}

resource "aws_security_group_rule" "internal_loki" {
  type              = "ingress"
  security_group_id = aws_security_group.internal.id
  description       = "Loki push and query API"
  from_port         = 3100
  to_port           = 3100
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.prod.cidr_block]
}

resource "aws_security_group_rule" "internal_tempo_query" {
  type              = "ingress"
  security_group_id = aws_security_group.internal.id
  description       = "Tempo query API"
  from_port         = 3200
  to_port           = 3200
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.prod.cidr_block]
}

resource "aws_security_group_rule" "internal_otlp" {
  type              = "ingress"
  security_group_id = aws_security_group.internal.id
  description       = "OTLP gRPC/HTTP (Tempo, Alloy)"
  from_port         = 4317
  to_port           = 4318
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.prod.cidr_block]
}

resource "aws_security_group_rule" "internal_alertmanager" {
  type              = "ingress"
  security_group_id = aws_security_group.internal.id
  description       = "Alertmanager UI/API"
  from_port         = 9093
  to_port           = 9093
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.prod.cidr_block]
}

resource "aws_security_group_rule" "internal_pushgateway" {
  type              = "ingress"
  security_group_id = aws_security_group.internal.id
  description       = "Pushgateway (batch job metrics)"
  from_port         = 9091
  to_port           = 9091
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.prod.cidr_block]
}

resource "aws_security_group_rule" "internal_blackbox" {
  type              = "ingress"
  security_group_id = aws_security_group.internal.id
  description       = "Blackbox exporter probe endpoint"
  from_port         = 9115
  to_port           = 9115
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.prod.cidr_block]
}

resource "aws_security_group_rule" "internal_alloy_metrics" {
  type              = "ingress"
  security_group_id = aws_security_group.internal.id
  description       = "Alloy self-metrics endpoint"
  from_port         = 12345
  to_port           = 12345
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.prod.cidr_block]
}

resource "aws_security_group_rule" "internal_egress" {
  #checkov:skip=CKV_AWS_382: image pulls, AWS APIs and the public uptime probes all leave through the NAT gateway; restricting egress would need a per-endpoint list that changes with every image bump
  type              = "egress"
  security_group_id = aws_security_group.internal.id
  description       = "Egress to AWS APIs, ECR and the public endpoints being probed"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "grafana" {
  name        = "${local.name}-grafana-sg"
  description = "Grafana: reachable from the prod ALB only"
  vpc_id      = data.aws_vpc.prod.id

  tags = merge(local.tags, { Name = "${local.name}-grafana" })
}

resource "aws_security_group_rule" "grafana_alb" {
  type                     = "ingress"
  security_group_id        = aws_security_group.grafana.id
  description              = "Grafana from the ALB"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_group.alb.id
}

resource "aws_security_group_rule" "grafana_egress" {
  #checkov:skip=CKV_AWS_382: Grafana queries the other monitoring endpoints and pulls its plugins
  type              = "egress"
  security_group_id = aws_security_group.grafana.id
  description       = "Egress to the monitoring endpoints and AWS APIs"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "efs" {
  #checkov:skip=CKV2_AWS_5: attached to the EFS mount target below (checkov cannot trace mount-target attachments)
  name        = "${local.name}-efs-sg"
  description = "Monitoring EFS: NFS from the monitoring tasks only"
  vpc_id      = data.aws_vpc.prod.id

  tags = merge(local.tags, { Name = "${local.name}-efs" })
}

resource "aws_security_group_rule" "efs_internal" {
  type                     = "ingress"
  security_group_id        = aws_security_group.efs.id
  description              = "NFS from the monitoring tasks"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internal.id
}

resource "aws_security_group_rule" "efs_grafana" {
  type                     = "ingress"
  security_group_id        = aws_security_group.efs.id
  description              = "NFS from Grafana"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.grafana.id
}

resource "aws_security_group_rule" "efs_tls_internal" {
  type                     = "ingress"
  security_group_id        = aws_security_group.efs.id
  description              = "NFS-over-TLS (stunnel) from the monitoring tasks"
  from_port                = 2996
  to_port                  = 2996
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internal.id
}

resource "aws_security_group_rule" "efs_tls_grafana" {
  type                     = "ingress"
  security_group_id        = aws_security_group.efs.id
  description              = "NFS-over-TLS (stunnel) from Grafana"
  from_port                = 2996
  to_port                  = 2996
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.grafana.id
}

resource "aws_security_group_rule" "efs_egress" {
  #checkov:skip=CKV_AWS_382: NFS replies leave via the VPC
  type              = "egress"
  security_group_id = aws_security_group.efs.id
  description       = "Egress to the VPC"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [data.aws_vpc.prod.cidr_block]
}
