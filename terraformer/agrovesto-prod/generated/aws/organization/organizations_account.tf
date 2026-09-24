resource "aws_organizations_account" "tfer--Agrovesto" {
  email     = "info@agrovesto.com"
  name      = "Agrovesto"
  parent_id = "r-y7qo"
}

resource "aws_organizations_account" "tfer--Agrovesto-Development" {
  email     = "tech@agrovesto.com"
  name      = "Agrovesto-Development"
  parent_id = "r-y7qo"
}
