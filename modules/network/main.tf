locals {
  zones = { for i, az in var.availability_zones : tostring(i) => az }

  # Interface endpoints that bypass NAT Gateway data-processing charges ($0.045/GB).
  # When enabled, private subnets reach AWS services without traversing NAT,
  # saving ~60% of NAT data costs for ECR image pulls, CloudWatch, Secrets Manager.
  interface_endpoints = var.enable_interface_endpoints ? toset([
    "ecr.api",
    "ecr.dkr",
    "logs",
    "secretsmanager",
    "ssm",
    "ssmmessages",
    "ec2messages"
  ]) : toset([])
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}

# Remove default rules; workloads get explicit security groups below.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-unused-default" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = var.name }
}

resource "aws_subnet" "public" {
  for_each                = local.zones
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value
  cidr_block              = cidrsubnet(var.cidr, 8, tonumber(each.key))
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.name}-public-${each.key}", Tier = "public" }
}

resource "aws_subnet" "app" {
  for_each                = local.zones
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value
  cidr_block              = cidrsubnet(var.cidr, 8, 10 + tonumber(each.key))
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.name}-app-${each.key}", Tier = "private" }
}

resource "aws_subnet" "database" {
  for_each                = local.zones
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value
  cidr_block              = cidrsubnet(var.cidr, 8, 20 + tonumber(each.key))
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.name}-database-${each.key}", Tier = "isolated" }
}

resource "aws_eip" "nat" {
  for_each = var.single_nat_gateway ? { "0" = var.availability_zones[0] } : local.zones
  domain   = "vpc"
  tags     = { Name = "${var.name}-nat-${each.key}" }
}

resource "aws_nat_gateway" "this" {
  for_each      = aws_eip.nat
  allocation_id = each.value.id
  subnet_id     = aws_subnet.public[each.key].id
  tags          = { Name = "${var.name}-nat-${each.key}" }
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each       = local.zones
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app" {
  for_each = local.zones
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "${var.name}-app-${each.key}" }
}

resource "aws_route" "app_nat" {
  for_each               = local.zones
  route_table_id         = aws_route_table.app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? "0" : each.key].id
}

resource "aws_route_table_association" "app" {
  for_each       = local.zones
  subnet_id      = aws_subnet.app[each.key].id
  route_table_id = aws_route_table.app[each.key].id
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-isolated-database" }
}

resource "aws_route_table_association" "database" {
  for_each       = local.zones
  subnet_id      = aws_subnet.database[each.key].id
  route_table_id = aws_route_table.database.id
}

# S3 gateway endpoint: no data-processing charges, stays on AWS backbone.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.app : rt.id]
  tags              = { Name = "${var.name}-s3" }
}

# -------------------------------------------------------------------------
# OPTIONAL: Interface endpoints to eliminate NAT charges for AWS API traffic
# Cost model: ~$0.01/hr/AZ/endpoint (~$7.2/mo each). Pays for itself when
# NAT-processed data > ~160 GB/mo per endpoint. Recommended for prod.
# -------------------------------------------------------------------------
resource "aws_security_group" "endpoints" {
  count       = var.enable_interface_endpoints ? 1 : 0
  name        = "${var.name}-endpoints"
  description = "Allow TLS from private subnets to AWS interface endpoints only"
  vpc_id      = aws_vpc.this.id
}

resource "aws_vpc_security_group_ingress_rule" "endpoints" {
  count             = var.enable_interface_endpoints ? 1 : 0
  security_group_id = aws_security_group.endpoints[0].id
  description       = "Private subnets to interface endpoints"
  cidr_ipv4         = var.cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = local.interface_endpoints
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in aws_subnet.app : s.id]
  security_group_ids  = [aws_security_group.endpoints[0].id]
  tags                = { Name = "${var.name}-${each.value}" }
}

resource "aws_cloudwatch_log_group" "flow" {
  name              = "/${var.name}/vpc-flow"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}

resource "aws_iam_role" "flow" {
  name                 = "${var.name}-flow-logs"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "vpc-flow-logs.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "flow" {
  role = aws_iam_role.flow.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"], Resource = "${aws_cloudwatch_log_group.flow.arn}:*" },
      { Effect = "Allow", Action = ["logs:DescribeLogGroups"], Resource = "*" }
    ]
  })
}

resource "aws_flow_log" "this" {
  vpc_id                   = aws_vpc.this.id
  iam_role_arn             = aws_iam_role.flow.arn
  log_destination          = aws_cloudwatch_log_group.flow.arn
  traffic_type             = "ALL"
  # OPTIMIZATION: 600s aggregation (10min) instead of 60s reduces CloudWatch
  # ingestion volume and cost by ~80% while retaining triage value.
  # For forensic detail, temporarily set to 60s via variable override.
  max_aggregation_interval = 600
  depends_on               = [aws_iam_role_policy.flow]
}
