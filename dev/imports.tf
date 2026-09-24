# =============================================================================
# One-shot import blocks: adopt the existing AWS resources into this stack's
# state (see docs/import-runbook.md). After the first clean apply they are
# no-ops; delete this file once `terraform plan` shows "No changes".
# =============================================================================

import {
  for_each = var.import_existing ? toset(["this"]) : toset([])
  to       = aws_vpc.main
  id       = "vpc-0d9b566c353787d53"
}

import {
  for_each = var.import_existing ? toset(["this"]) : toset([])
  to       = aws_internet_gateway.main
  id       = "igw-04e4d65d903b2b67d"
}

# Default SG has 0 rules today, so the deny-all design changes nothing.
import {
  for_each = var.import_existing ? toset(["this"]) : toset([])
  to       = aws_default_security_group.default[0]
  id       = "sg-032197de8d143373f"
}

# One public subnet by design: the one the running app host is in.
import {
  for_each = var.import_existing ? toset(["this"]) : toset([])
  to       = aws_subnet.public[0]
  id       = "subnet-0739cfd4c412deb3f" # 172.96.0.0/24 eu-west-1a
}

import {
  for_each = var.import_existing ? toset(["this"]) : toset([])
  to       = aws_route_table.public
  id       = "rtb-018e7f1b9df073189"
}

import {
  for_each = var.import_existing ? toset(["this"]) : toset([])
  to       = aws_route_table_association.public[0]
  id       = "subnet-0739cfd4c412deb3f/rtb-018e7f1b9df073189"
}

import {
  for_each = var.import_existing ? toset(["this"]) : toset([])
  to       = aws_route.internet
  id       = "rtb-018e7f1b9df073189_0.0.0.0/0"
}

# --- Amplify ------------------------------------------------------------------
import {
  for_each = var.import_existing ? toset(["this"]) : toset([])
  to       = aws_amplify_app.this["onboarding"]
  id       = "d3v79u00ot9glq" # onboarding-frontend, branch dev
}

import {
  for_each = var.import_existing ? toset(["this"]) : toset([])
  to       = aws_amplify_branch.this["onboarding"]
  id       = "d3v79u00ot9glq/dev"
}

import {
  for_each = var.import_existing ? toset(["this"]) : toset([])
  to       = aws_amplify_app.this["landing"]
  id       = "dfvk5chhp2iln" # nomaos-landingpage
}

import {
  for_each = var.import_existing ? toset(["this"]) : toset([])
  to       = aws_amplify_branch.this["landing"]
  id       = "dfvk5chhp2iln/staging"
}

# NOT adopted: the running host i-00af32231113d64f9 (new-noma-api) and its EIP.
# It is t3.medium on a custom AMI with a 500 GB gp2 root disk and SQL Server
# inside. The new design is a fresh Ubuntu host with separate data volumes.
# Adopting it as aws_instance.app would force a replacement (different AMI)
# and destroy the live server. It is left unmanaged; the new
# host is built next to it, and the EIP moves at cut-over (docs/import-runbook.md §5).
