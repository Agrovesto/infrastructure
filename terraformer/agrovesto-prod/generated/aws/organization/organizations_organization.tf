resource "aws_organizations_organization" "tfer--Agrovesto" {
  aws_service_access_principals = ["cost-optimization-hub.bcm.amazonaws.com", "iam.amazonaws.com", "ssm.amazonaws.com", "sso.amazonaws.com", "user-subscriptions.amazonaws.com"]
  enabled_policy_types          = ["RESOURCE_CONTROL_POLICY"]
  feature_set                   = "ALL"
}

resource "aws_organizations_organization" "tfer--Agrovesto-Development" {
  aws_service_access_principals = ["cost-optimization-hub.bcm.amazonaws.com", "iam.amazonaws.com", "ssm.amazonaws.com", "sso.amazonaws.com", "user-subscriptions.amazonaws.com"]
  enabled_policy_types          = ["RESOURCE_CONTROL_POLICY"]
  feature_set                   = "ALL"
}
