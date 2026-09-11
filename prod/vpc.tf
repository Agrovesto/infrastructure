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
  count = length(aws_subnet.public)

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
  count = length(aws_subnet.private)

  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, { Name = "${local.name}-private-rt-${count.index + 1}" })
}

resource "aws_route" "private_nat" {
  count = length(aws_subnet.private)

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

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
  count = length(aws_subnet.database)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.private[count.index % length(aws_route_table.private)].id
}

resource "aws_db_subnet_group" "mssql" {
  name       = "${local.name}-mssql"
  subnet_ids = aws_subnet.database[*].id

  tags = merge(local.tags, { Name = "${local.name}-mssql-subnets" })
}
