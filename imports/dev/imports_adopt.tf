# =============================================================================
# DEV (353833416626) — ADOPT existing resources into the NEW design's addresses
#
# "Import the old one and use it for the new infra, no repetition": each block
# below makes Terraform take over an existing resource at the address the new
# code already declares, instead of creating a second copy.
#
# Staged into dev/ by `imports/stage.sh dev` (never committed there). Delete by
# `imports/stage.sh --unstage dev` after the first successful apply.
#
# Commented slots need an ID printed by `imports/discover.sh dev`. Before you
# uncomment them, match the variables in dev/terraform.auto.tfvars to the real
# values. Otherwise the plan shows replace (-/+), not import. See RUNBOOK §4.
# =============================================================================

# --- Network -----------------------------------------------------------------
# vpc_cidr in dev/terraform.auto.tfvars MUST equal this VPC's CIDR
# (discover.sh: "VPC"). cidr_block is ForceNew.
import {
  to = aws_vpc.main
  id = "vpc-0d9b566c353787d53"
}

import {
  to = aws_internet_gateway.main
  id = "igw-04e4d65d903b2b67d"
}

# Default SG of the VPC (discover.sh: "SG ... DEFAULT"). The new code strips
# its rules (deny-all) - check nothing still relies on them.
# import {
#   to = aws_default_security_group.default
#   id = "sg-XXXXXXXX"
# }

# Dev design = ONE public subnet. Pick the subnet that routes 0.0.0.0/0 to the
# IGW (discover.sh: "SUBNET ... public"), set public_subnet_cidrs = ["<its cidr>"]
# and make sure its AZ is the first available AZ (or it is ForceNew).
# The other 3 subnets stay as legacy imports in imports_legacy.tf.
# import {
#   to = aws_subnet.public[0]
#   id = "subnet-XXXXXXXX"
# }
# import {
#   to = aws_route_table.public
#   id = "rtb-XXXXXXXX"
# }
# import {
#   to = aws_route_table_association.public[0]
#   id = "subnet-XXXXXXXX/rtb-XXXXXXXX"
# }
# import {
#   to = aws_route.internet
#   id = "rtb-XXXXXXXX_0.0.0.0/0"
# }

# --- App host (optional adoption) ---------------------------------------------
# i-00af32231113d64f9 is the live, SSM-managed host. Adopting it as
# aws_instance.app needs var.ami_id = its AMI (ami is ForceNew) and
# instance_type/subnet/key_name to match; user_data changes then apply as an
# in-place stop/start. If you would rather build a fresh host from the new
# design, leave this commented: it stays a legacy import instead.
# import {
#   to = aws_instance.app
#   id = "i-00af32231113d64f9"
# }
# import {
#   to = aws_eip.app[0]
#   id = "eipalloc-0b7f04c0906f47a4e"
# }
# import {
#   to = aws_eip_association.app[0]
#   id = "eipassoc-XXXXXXXX"   # discover.sh: "EIP ... assoc"
# }

# --- Amplify -------------------------------------------------------------------
# amplify_apps.onboarding (repo onboarding-frontend, branch "dev") already
# exists as d3v79u00ot9glq / branch dev. `name` is in-place, not ForceNew.
import {
  to = aws_amplify_app.this["onboarding"]
  id = "d3v79u00ot9glq"
}

import {
  to = aws_amplify_branch.this["onboarding"]
  id = "d3v79u00ot9glq/dev"
}
