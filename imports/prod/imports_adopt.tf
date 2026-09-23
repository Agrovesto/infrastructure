# =============================================================================
# PROD (221434544570) — ADOPT existing resources into the NEW design's addresses
#
# Staged into prod/ by `imports/stage.sh prod` (never committed there).
# Commented slots need an ID from `imports/discover.sh prod`. See RUNBOOK §4.
# =============================================================================

# --- Network -----------------------------------------------------------------
# vpc_cidr in prod/terraform.auto.tfvars MUST equal this VPC's CIDR.
import {
  to = aws_vpc.main
  id = "vpc-0016f521bae08f4ff"
}

import {
  to = aws_internet_gateway.main
  id = "igw-07275a1a62726a4c8"
}

# import {
#   to = aws_default_security_group.default
#   id = "sg-XXXXXXXX"
# }

# The existing VPC has 4 subnets. The new design wants public x2, private x2 and
# database x2. Map whatever matches: discover.sh shows each subnet's CIDR, AZ
# and route (IGW = public, NAT/none = private). Set public_subnet_cidrs,
# private_subnet_cidrs and database_subnet_cidrs so these indexes line up. The
# design creates any slots with nothing to adopt (e.g. database subnets).
# import {
#   to = aws_subnet.public[0]
#   id = "subnet-XXXXXXXX"
# }
# import {
#   to = aws_subnet.public[1]
#   id = "subnet-XXXXXXXX"
# }
# import {
#   to = aws_route_table.public
#   id = "rtb-XXXXXXXX"
# }
# import {
#   to = aws_subnet.private[0]
#   id = "subnet-XXXXXXXX"
# }
# import {
#   to = aws_subnet.private[1]
#   id = "subnet-XXXXXXXX"
# }

# --- RDS SQL Server ------------------------------------------------------------
# migration-prod becomes aws_db_instance.mssql. Required tfvars (RUNBOOK §4.2):
#   mssql_identifier     = "migration-prod"
#   mssql_engine / mssql_engine_version / mssql_instance_class /
#   mssql_allocated_storage_gb / mssql_storage_type / mssql_port /
#   mssql_master_username  = the values discover.sh prints
# The instance already uses an RDS-managed master secret (rds!db-...), which is
# exactly what the new code expects - no password ever enters state.
import {
  to = aws_db_instance.mssql
  id = "migration-prod"
}

# Its subnet group (discover.sh: "RDS ... subnet_group"). The subnet group name
# is ForceNew on the instance, so adopt it: set mssql_subnet_group_name to it.
# import {
#   to = aws_db_subnet_group.mssql
#   id = "XXXXXXXX"
# }

# Its security group (discover.sh: "RDS ... sg"). Adopted as the RDS SG; rules
# are then reconciled to "1433 from the ECS SG only" (review the plan!).
# import {
#   to = aws_security_group.rds
#   id = "sg-XXXXXXXX"
# }
