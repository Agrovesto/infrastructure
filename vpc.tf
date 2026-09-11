# =============================================================================
# VPC — single public subnet + internet gateway (dev)
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { Name = "${local.name}-vpc" })
}

# Deny-all default security group: nothing uses it (the EC2 host has its own
# SG), so strip its default allow-all-self rules (CKV2_AWS_12).
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, { Name = "${local.name}-default-sg" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, { Name = "${local.name}-igw" })
}

# Single public subnet by design (no NAT gateway in dev) - mirrors checkov CKV_AWS_130 skip.
#trivy:ignore:AVD-AWS-0164
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

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
