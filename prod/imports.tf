# =============================================================================
# One-shot import blocks: adopt the existing AWS resources into this stack's
# state (see docs/import-runbook.md). After the first clean apply they are
# no-ops; delete this file once `terraform plan` shows "No changes".
# =============================================================================

import {
  to = aws_vpc.main
  id = "vpc-0016f521bae08f4ff"
}

import {
  to = aws_internet_gateway.main
  id = "igw-07275a1a62726a4c8"
}

# Public: the two IGW-routed subnets.
import {
  to = aws_subnet.public[0]
  id = "subnet-0b808deeaf8391867" # 172.96.0.0/24 eu-west-1a
}

import {
  to = aws_subnet.public[1]
  id = "subnet-0e169f40c70cdfe8b" # 172.96.1.0/24 eu-west-1b (noma-agx EC2)
}

# The existing public subnets each have their own route table. The design has
# ONE shared table: adopt rtb-0530… and re-point subnet-0e169… at it. The
# other table (rtb-0614…) is left unmanaged and can be deleted later.
import {
  to = aws_route_table.public
  id = "rtb-0530eb261b38f735b"
}

import {
  to = aws_route_table_association.public[0]
  id = "subnet-0b808deeaf8391867/rtb-0530eb261b38f735b"
}

# subnet-0e169… is associated with rtb-0614… today. Importing that association
# into public[1] makes the plan an in-place ReplaceRouteTableAssociation to
# rtb-0530…, which has the same IGW route, so there is no connectivity gap.
import {
  to = aws_route_table_association.public[1]
  id = "subnet-0e169f40c70cdfe8b/rtb-0614ed06de1bc1d89"
}

import {
  to = aws_route.public_internet
  id = "rtb-0530eb261b38f735b_0.0.0.0/0"
}

# Database: the two isolated subnets that migration-prod's subnet group
# (agxdb2subnetgroup) already uses. Adopting them keeps the instance in place.
import {
  to = aws_subnet.database[0]
  id = "subnet-00ee6901e53783c86" # 172.96.2.0/24 eu-west-1a
}

import {
  to = aws_subnet.database[1]
  id = "subnet-084f21457f316c44c" # 172.96.3.0/24 eu-west-1b
}

# Their route tables become the design's private tables. They gain the NAT
# route, and the new private subnets (172.96.11/12.0/24) share them.
import {
  to = aws_route_table.private[0]
  id = "rtb-0fa42099da11b78e9"
}

import {
  to = aws_route_table.private[1]
  id = "rtb-084528a52ec739f38"
}

import {
  to = aws_route_table_association.database[0]
  id = "subnet-00ee6901e53783c86/rtb-0fa42099da11b78e9"
}

import {
  to = aws_route_table_association.database[1]
  id = "subnet-084f21457f316c44c/rtb-084528a52ec739f38"
}

# --- DNS: both zones already exist -------------------------------------------
import {
  to = aws_route53_zone.this[0]
  id = "Z0208643NZ0W8WF5RQ9F" # nomaos.com
}

import {
  to = aws_route53_zone.agrovesto
  id = "Z00055662LTUSSMS5ZA84" # agrovesto.com
}

# --- RDS SQL Server: migration-prod -------------------------------------------
import {
  to = aws_db_instance.mssql
  id = "migration-prod"
}

import {
  to = aws_db_subnet_group.mssql
  id = "agxdb2subnetgroup"
}

# NOT adopted:
#  * ACM *.nomaos.com (5172b3e7…) has no apex SAN, and the design's cert needs
#    one, so the design creates a new cert. The old one is left unmanaged
#    (unused, delete later).
#  * The default SG sg-05a2722a… has 8 live rules and is attached to
#    migration-prod and the EC2 host, so it is left unmanaged, as-is
#    (manage_default_security_group = false).
