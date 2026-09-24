# =============================================================================
# DEV (353833416626) — ADOPT existing resources into the NEW design's addresses
# Values come from imports/discovery-dev.txt (2026-09-23).
# Matching tfvars: dev/terraform.auto.tfvars, "Adoption" section.
# =============================================================================

# --- Network: vpc-0d9b566c353787d53  172.96.0.0/16 ------------------------------
import {
  to = aws_vpc.main
  id = "vpc-0d9b566c353787d53"
}

import {
  to = aws_internet_gateway.main
  id = "igw-04e4d65d903b2b67d"
}

# Default SG has 0 rules today, so the deny-all design changes nothing.
import {
  to = aws_default_security_group.default[0]
  id = "sg-032197de8d143373f"
}

# One public subnet by design: the one the running app host is in.
import {
  to = aws_subnet.public[0]
  id = "subnet-0739cfd4c412deb3f" # 172.96.0.0/24 eu-west-1a
}

import {
  to = aws_route_table.public
  id = "rtb-018e7f1b9df073189"
}

import {
  to = aws_route_table_association.public[0]
  id = "subnet-0739cfd4c412deb3f/rtb-018e7f1b9df073189"
}

import {
  to = aws_route.internet
  id = "rtb-018e7f1b9df073189_0.0.0.0/0"
}

# --- Amplify ------------------------------------------------------------------
import {
  to = aws_amplify_app.this["onboarding"]
  id = "d3v79u00ot9glq" # onboarding-frontend, branch dev
}

import {
  to = aws_amplify_branch.this["onboarding"]
  id = "d3v79u00ot9glq/dev"
}

import {
  to = aws_amplify_app.this["landing"]
  id = "dfvk5chhp2iln" # nomaos-landingpage
}

import {
  to = aws_amplify_branch.this["landing"]
  id = "dfvk5chhp2iln/staging"
}

# NOT adopted: the running host i-00af32231113d64f9 (new-noma-api) and its EIP.
# It is t3.medium on a custom AMI with a 500 GB gp2 root disk and SQL Server
# inside. The new design is a fresh Ubuntu host with separate data volumes.
# Adopting it as aws_instance.app would force a replacement (different AMI)
# and destroy the live server. It is imported as legacy_* instead; the new
# host is built next to it, and the EIP moves at cut-over (RUNBOOK §4.3).
