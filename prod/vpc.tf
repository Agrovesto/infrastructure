# =============================================================================
# VPC — public subnets (ALB), private subnets (ECS tasks), db subnets (RDS)
#
# Traffic path:
#   Internet -> ALB (public subnets) -> ECS tasks (private subnets)
#   Private/db subnets reach the internet through the NAT gateways
#   (ECR image pulls, CloudWatch, Secrets Manager).
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { Name = "${local.name}-vpc" })
}

# Deny-all default security group: nothing uses it, so strip its default
# allow-all-self rules (CKV2_AWS_12).
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, { Name = "${local.name}-default-sg" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, { Name = "${local.name}-igw" })
}

# -----------------------------------------------------------------------------
# Public subnets (ALB only)
# -----------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    Name = "${local.name}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, { Name = "${local.name}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# NAT gateways (EIP per NAT) — outbound path for the private subnets
# -----------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count = local.nat_count

  domain = "vpc"

  tags = merge(local.tags, { Name = "${local.name}-nat-eip-${count.index + 1}" })
}

resource "aws_nat_gateway" "main" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.main]

  tags = merge(local.tags, { Name = "${local.name}-nat-${count.index + 1}" })
}

# -----------------------------------------------------------------------------
# Private subnets (ECS Fargate tasks)
# -----------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    Name = "${local.name}-private-${count.index + 1}"
    Tier = "private"
  })
}

# One route table per private subnet, each pointing at its AZ's NAT gateway
# (or the single shared one when var.single_nat_gateway = true).
resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, { Name = "${local.name}-private-rt-${count.index + 1}" })
}

resource "aws_route" "private_nat" {
  # Count off the *variable*, not off aws_subnet.private: referencing the
  # resource here makes count unknown until apply, which Terraform rejects
  # ("The count value depends on resource attributes..."). The two are the
  # same number before and after the fix, so no state change.
  count = length(var.private_subnet_cidrs)

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
}

resource "aws_route_table_association" "private" {
  # See aws_route.private_nat: count must come from the variable so it is
  # known at plan time.
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# -----------------------------------------------------------------------------
# Database subnets (RDS SQL Server)
# -----------------------------------------------------------------------------

resource "aws_subnet" "database" {
  count = length(var.database_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.database_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    Name = "${local.name}-db-${count.index + 1}"
    Tier = "database"
  })
}

# Database subnets share the private NAT route tables: RDS needs no internet
# itself, but the association keeps every non-public subnet off the IGW.
resource "aws_route_table_association" "database" {
  count = length(var.database_subnet_cidrs)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.private[count.index % length(var.private_subnet_cidrs)].id
}

resource "aws_db_subnet_group" "mssql" {
  name       = "${local.name}-mssql"
  subnet_ids = aws_subnet.database[*].id

  tags = merge(local.tags, { Name = "${local.name}-mssql-subnets" })
}

# -----------------------------------------------------------------------------
# VPC flow logs -> CloudWatch (prod audit trail)
# -----------------------------------------------------------------------------

# CloudWatch default encryption is enough here too - mirrors checkov CKV_AWS_158 skip.
#trivy:ignore:AVD-AWS-0017
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/vpc/${local.name}/flow-logs"
  retention_in_days = var.log_retention_days

  tags = merge(local.tags, { Name = "${local.name}-flow-logs" })
}

resource "aws_iam_role" "flow_logs" {
  name               = "${local.name}-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume.json != "" ? data.aws_iam_policy_document.flow_logs_assume.json : "{\"Version\":\"2012-10-17\",\"Statement\":[]}"

  tags = local.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "${local.name}-flow-logs-policy"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs.json != "" ? data.aws_iam_policy_document.flow_logs.json : "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
}

resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs.arn

  tags = merge(local.tags, { Name = "${local.name}-flow-log" })
}
