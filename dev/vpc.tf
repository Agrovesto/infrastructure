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
  # Declaring this resource takes over the VPC's default SG and REMOVES all
  # of its rules. Turn it off when adopting a VPC whose default SG is in use
  # (it is then imported with its real rules as a legacy resource instead).
  count = var.manage_default_security_group ? 1 : 0

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
  # Count off the variable, not off aws_subnet.public, so it is known at plan
  # time (same latent bug fixed in prod/vpc.tf).
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
