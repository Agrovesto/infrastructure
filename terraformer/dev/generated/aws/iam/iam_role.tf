resource "aws_iam_role" "tfer--AWSCodePipelineServiceRole-eu-west-1-nomaos" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "353833416626"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Sid": "CodePipelineTrustPolicy"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "AmplifyCdkAssetPublishing"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"s3:PutObject\",\"s3:GetObject\",\"s3:ListBucket\",\"s3:DeleteObject\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1\",\"arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1/*\"],\"Sid\":\"AllowAmplifyToPublishCDKAssets\"}]}"
  }

  inline_policy {
    name   = "AmplifyCdkBootstrapAccess"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":\"ssm:GetParameter\",\"Effect\":\"Allow\",\"Resource\":\"arn:aws:ssm:eu-central-1:353833416626:parameter/cdk-bootstrap/hnb659fds/version\",\"Sid\":\"AllowAmplifyToReadCDKBootstrap\"}]}"
  }

  inline_policy {
    name   = "codepipeline"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"logs:CreateLogGroup\",\"logs:CreateLogStream\",\"logs:PutLogEvents\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:logs:eu-west-1:353833416626:log-group:/aws/codepipeline/*\"],\"Sid\":\"AllowCloudWatchLogs\"},{\"Action\":[\"ec2:DescribeInstances\",\"ec2:DescribeTags\",\"ec2:DescribeInstanceStatus\"],\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"AllowEC2Describe\"},{\"Action\":[\"ssm:SendCommand\",\"ssm:ListCommands\",\"ssm:ListCommandInvocations\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:ec2:eu-west-1:353833416626:instance/*\",\"arn:aws:ssm:eu-west-1:353833416626:document/*\"],\"Sid\":\"AllowSSMSendCommand\"},{\"Action\":[\"s3:GetObject\",\"s3:GetObjectVersion\"],\"Effect\":\"Allow\",\"Resource\":\"arn:aws:s3:::codepipeline-eu-west-1-3bf3ec101df5-4d09-9689-376482a069ed/*\",\"Sid\":\"AllowCodePipelineS3Access\"}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::353833416626:policy/service-role/AWSCodePipelineServiceRole-eu-west-1-nomaos", "arn:aws:iam::353833416626:policy/service-role/CodePipeline-CodeConnections-eu-west-1-nomaos", "arn:aws:iam::aws:policy/AWSCodeDeployFullAccess", "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess", "arn:aws:iam::aws:policy/AmazonSSMFullAccess", "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"]
  max_session_duration = "3600"
  name                 = "AWSCodePipelineServiceRole-eu-west-1-nomaos"
  path                 = "/service-role/"
}

resource "aws_iam_role" "tfer--AWSReservedSSO_AdministratorAccess_0b70d56e4b20d17b" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "sts:AssumeRoleWithSAML",
        "sts:TagSession"
      ],
      "Condition": {
        "StringEquals": {
          "SAML:aud": "https://signin.aws.amazon.com/saml"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::353833416626:saml-provider/AWSSSO_df55f9ab23f2f233_DO_NOT_DELETE"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  max_session_duration = "43200"
  name                 = "AWSReservedSSO_AdministratorAccess_0b70d56e4b20d17b"
  path                 = "/aws-reserved/sso.amazonaws.com/eu-west-1/"
}

resource "aws_iam_role" "tfer--AWSServiceRoleForAmazonSSM" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ssm.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "Provides access to AWS Resources managed or used by Amazon SSM."
  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/AmazonSSMServiceRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForAmazonSSM"
  path                 = "/aws-service-role/ssm.amazonaws.com/"
}

resource "aws_iam_role" "tfer--AWSServiceRoleForAppRunner" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "apprunner.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/AppRunnerServiceRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForAppRunner"
  path                 = "/aws-service-role/apprunner.amazonaws.com/"
}

resource "aws_iam_role" "tfer--AWSServiceRoleForAutoScaling" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "autoscaling.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "Default Service-Linked Role enables access to AWS Services and Resources used or managed by Auto Scaling"
  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/AutoScalingServiceRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForAutoScaling"
  path                 = "/aws-service-role/autoscaling.amazonaws.com/"
}

resource "aws_iam_role" "tfer--AWSServiceRoleForAwsUserNotifications" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "notifications.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "The Service Linked Role used by AWS User Notifications."
  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/AWSUserNotificationsServiceLinkedRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForAwsUserNotifications"
  path                 = "/aws-service-role/notifications.amazonaws.com/"
}

resource "aws_iam_role" "tfer--AWSServiceRoleForCostOptimizationHub" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "cost-optimization-hub.bcm.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/CostOptimizationHubServiceRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForCostOptimizationHub"
  path                 = "/aws-service-role/cost-optimization-hub.bcm.amazonaws.com/"
}

resource "aws_iam_role" "tfer--AWSServiceRoleForECS" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "Policy to enable Amazon ECS to manage your EC2 instances and related resources."
  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/AmazonECSServiceRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForECS"
  path                 = "/aws-service-role/ecs.amazonaws.com/"
}

resource "aws_iam_role" "tfer--AWSServiceRoleForElasticLoadBalancing" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "elasticloadbalancing.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "Allows ELB to call AWS services on your behalf."
  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/AWSElasticLoadBalancingServiceRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForElasticLoadBalancing"
  path                 = "/aws-service-role/elasticloadbalancing.amazonaws.com/"
}

resource "aws_iam_role" "tfer--AWSServiceRoleForOrganizations" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "organizations.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "Service-linked role used by AWS Organizations to enable integration of other AWS services with Organizations."
  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/AWSOrganizationsServiceTrustPolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForOrganizations"
  path                 = "/aws-service-role/organizations.amazonaws.com/"
}

resource "aws_iam_role" "tfer--AWSServiceRoleForRDS" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "rds.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "Allows Amazon RDS to manage AWS resources on your behalf"
  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/AmazonRDSServiceRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForRDS"
  path                 = "/aws-service-role/rds.amazonaws.com/"
}

resource "aws_iam_role" "tfer--AWSServiceRoleForResourceExplorer" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "resource-explorer-2.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/AWSResourceExplorerServiceRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForResourceExplorer"
  path                 = "/aws-service-role/resource-explorer-2.amazonaws.com/"
}

resource "aws_iam_role" "tfer--AWSServiceRoleForSSO" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "sso.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "Service-linked role used by AWS SSO to manage AWS resources, including IAM roles, policies and SAML IdP on your behalf."
  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/AWSSSOServiceRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForSSO"
  path                 = "/aws-service-role/sso.amazonaws.com/"
}

resource "aws_iam_role" "tfer--AWSServiceRoleForServiceQuotas" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "servicequotas.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "A service-linked role is required for Service Quotas to access your service limits."
  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/ServiceQuotasServiceRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForServiceQuotas"
  path                 = "/aws-service-role/servicequotas.amazonaws.com/"
}

resource "aws_iam_role" "tfer--AWSServiceRoleForSupport" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "support.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "Enables resource access for AWS to provide billing, administrative and support services"
  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/AWSSupportServiceRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForSupport"
  path                 = "/aws-service-role/support.amazonaws.com/"
}

resource "aws_iam_role" "tfer--AWSServiceRoleForTrustedAdvisor" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "trustedadvisor.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "Access for the AWS Trusted Advisor Service to help reduce cost, increase performance, and improve security of your AWS environment."
  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/AWSTrustedAdvisorServiceRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForTrustedAdvisor"
  path                 = "/aws-service-role/trustedadvisor.amazonaws.com/"
}

resource "aws_iam_role" "tfer--AmplifySSRLoggingRole-4fb94426-a00e-4cd2-9ea2-2d0bd82fd3e1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "amplify.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "The service role that will be used by AWS Amplify for Web Compute app logging."
  managed_policy_arns  = ["arn:aws:iam::353833416626:policy/service-role/AmplifySSRLoggingPolicy-4fb94426-a00e-4cd2-9ea2-2d0bd82fd3e1"]
  max_session_duration = "3600"
  name                 = "AmplifySSRLoggingRole-4fb94426-a00e-4cd2-9ea2-2d0bd82fd3e1"
  path                 = "/service-role/"
}

resource "aws_iam_role" "tfer--AmplifySSRLoggingRole-640973d5-6399-421a-ac2a-ba65df815c56" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "amplify.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "The service role that will be used by AWS Amplify for Web Compute app logging."
  managed_policy_arns  = ["arn:aws:iam::353833416626:policy/service-role/AmplifySSRLoggingPolicy-640973d5-6399-421a-ac2a-ba65df815c56"]
  max_session_duration = "3600"
  name                 = "AmplifySSRLoggingRole-640973d5-6399-421a-ac2a-ba65df815c56"
  path                 = "/service-role/"
}

resource "aws_iam_role" "tfer--AmplifySSRLoggingRole-702a70a4-375c-468f-97d4-4641dd448284" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "amplify.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "The service role that will be used by AWS Amplify for Web Compute app logging."
  managed_policy_arns  = ["arn:aws:iam::353833416626:policy/service-role/AmplifySSRLoggingPolicy-702a70a4-375c-468f-97d4-4641dd448284"]
  max_session_duration = "3600"
  name                 = "AmplifySSRLoggingRole-702a70a4-375c-468f-97d4-4641dd448284"
  path                 = "/service-role/"
}

resource "aws_iam_role" "tfer--AmplifySSRLoggingRole-739d4bc2-0a8d-4a1b-9796-ea41cf9cfc87" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "amplify.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "The service role that will be used by AWS Amplify for Web Compute app logging."
  managed_policy_arns  = ["arn:aws:iam::353833416626:policy/service-role/AmplifySSRLoggingPolicy-739d4bc2-0a8d-4a1b-9796-ea41cf9cfc87"]
  max_session_duration = "3600"
  name                 = "AmplifySSRLoggingRole-739d4bc2-0a8d-4a1b-9796-ea41cf9cfc87"
  path                 = "/service-role/"
}

resource "aws_iam_role" "tfer--AmplifySSRLoggingRole-77230cc0-0b08-4dc4-be4b-98f0a92c9b9b" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "amplify.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "The service role that will be used by AWS Amplify for Web Compute app logging."
  managed_policy_arns  = ["arn:aws:iam::353833416626:policy/service-role/AmplifySSRLoggingPolicy-77230cc0-0b08-4dc4-be4b-98f0a92c9b9b"]
  max_session_duration = "3600"
  name                 = "AmplifySSRLoggingRole-77230cc0-0b08-4dc4-be4b-98f0a92c9b9b"
  path                 = "/service-role/"
}

resource "aws_iam_role" "tfer--AmplifySSRLoggingRole-9ceec546-7451-41f6-8409-410781242368" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "amplify.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "The service role that will be used by AWS Amplify for Web Compute app logging."
  managed_policy_arns  = ["arn:aws:iam::353833416626:policy/service-role/AmplifySSRLoggingPolicy-9ceec546-7451-41f6-8409-410781242368"]
  max_session_duration = "3600"
  name                 = "AmplifySSRLoggingRole-9ceec546-7451-41f6-8409-410781242368"
  path                 = "/service-role/"
}

resource "aws_iam_role" "tfer--AmplifySSRLoggingRole-c0c3ebab-fdb6-4ed4-a8fb-2ce7dd34f371" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "amplify.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "The service role that will be used by AWS Amplify for Web Compute app logging."
  managed_policy_arns  = ["arn:aws:iam::353833416626:policy/service-role/AmplifySSRLoggingPolicy-c0c3ebab-fdb6-4ed4-a8fb-2ce7dd34f371"]
  max_session_duration = "3600"
  name                 = "AmplifySSRLoggingRole-c0c3ebab-fdb6-4ed4-a8fb-2ce7dd34f371"
  path                 = "/service-role/"
}

resource "aws_iam_role" "tfer--GitHubActionsCDKDeploy" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:Agrovesto/*:*"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::353833416626:oidc-provider/token.actions.githubusercontent.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AWSCloudFormationFullAccess", "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser", "arn:aws:iam::aws:policy/AmazonEC2FullAccess", "arn:aws:iam::aws:policy/AmazonECS_FullAccess", "arn:aws:iam::aws:policy/AmazonRDSFullAccess", "arn:aws:iam::aws:policy/AmazonS3FullAccess", "arn:aws:iam::aws:policy/AmazonSSMFullAccess", "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds", "arn:aws:iam::aws:policy/IAMFullAccess", "arn:aws:iam::aws:policy/SecretsManagerReadWrite"]
  max_session_duration = "3600"
  name                 = "GitHubActionsCDKDeploy"
  path                 = "/"
}

resource "aws_iam_role" "tfer--GuestEntryIAMRoleffc357-beg42uuyereqjerfalxrk72nmq-NONE" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "DynamoDBAccess"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"dynamodb:BatchGetItem\",\"dynamodb:BatchWriteItem\",\"dynamodb:PutItem\",\"dynamodb:DeleteItem\",\"dynamodb:GetItem\",\"dynamodb:Scan\",\"dynamodb:Query\",\"dynamodb:UpdateItem\",\"dynamodb:ConditionCheckItem\",\"dynamodb:DescribeTable\",\"dynamodb:GetRecords\",\"dynamodb:GetShardIterator\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:dynamodb:eu-central-1:353833416626:table/GuestEntry-beg42uuyereqjerfalxrk72nmq-NONE\",\"arn:aws:dynamodb:eu-central-1:353833416626:table/GuestEntry-beg42uuyereqjerfalxrk72nmq-NONE/*\"]}]}"
  }

  max_session_duration = "3600"
  name                 = "GuestEntryIAMRoleffc357-beg42uuyereqjerfalxrk72nmq-NONE"
  path                 = "/"

  tags = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyData"
    created-by                = "amplify"
  }

  tags_all = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyData"
    created-by                = "amplify"
  }
}

resource "aws_iam_role" "tfer--MediaItemIAMRole3fae1c-beg42uuyereqjerfalxrk72nmq-NONE" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "DynamoDBAccess"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"dynamodb:BatchGetItem\",\"dynamodb:BatchWriteItem\",\"dynamodb:PutItem\",\"dynamodb:DeleteItem\",\"dynamodb:GetItem\",\"dynamodb:Scan\",\"dynamodb:Query\",\"dynamodb:UpdateItem\",\"dynamodb:ConditionCheckItem\",\"dynamodb:DescribeTable\",\"dynamodb:GetRecords\",\"dynamodb:GetShardIterator\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:dynamodb:eu-central-1:353833416626:table/MediaItem-beg42uuyereqjerfalxrk72nmq-NONE\",\"arn:aws:dynamodb:eu-central-1:353833416626:table/MediaItem-beg42uuyereqjerfalxrk72nmq-NONE/*\"]}]}"
  }

  max_session_duration = "3600"
  name                 = "MediaItemIAMRole3fae1c-beg42uuyereqjerfalxrk72nmq-NONE"
  path                 = "/"

  tags = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyData"
    created-by                = "amplify"
  }

  tags_all = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyData"
    created-by                = "amplify"
  }
}

resource "aws_iam_role" "tfer--OrganizationAccountAccessRole" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::221434544570:root"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  max_session_duration = "3600"
  name                 = "OrganizationAccountAccessRole"
  path                 = "/"
}

resource "aws_iam_role" "tfer--agrovesto-infra-deploymen-CustomVpcRestrictDefaultS-wHppFzTSRAd1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "Inline"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"ec2:AuthorizeSecurityGroupIngress\",\"ec2:AuthorizeSecurityGroupEgress\",\"ec2:RevokeSecurityGroupIngress\",\"ec2:RevokeSecurityGroupEgress\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:ec2:eu-west-1:353833416626:security-group/sg-032197de8d143373f\"]}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
  max_session_duration = "3600"
  name                 = "agrovesto-infra-deploymen-CustomVpcRestrictDefaultS-wHppFzTSRAd1"
  path                 = "/"
}

resource "aws_iam_role" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-DTg5g94z5aY6" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "SecretsManagerRDSSQLServerRotationSingleUserRolePolicy0"
    policy = "{\"Statement\":[{\"Action\":[\"ec2:CreateNetworkInterface\",\"ec2:DeleteNetworkInterface\",\"ec2:DescribeNetworkInterfaces\",\"ec2:DetachNetworkInterface\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
  }

  inline_policy {
    name   = "SecretsManagerRDSSQLServerRotationSingleUserRolePolicy1"
    policy = "{\"Statement\":[{\"Action\":[\"secretsmanager:DescribeSecret\",\"secretsmanager:GetSecretValue\",\"secretsmanager:PutSecretValue\",\"secretsmanager:UpdateSecretVersionStage\"],\"Condition\":{\"StringEquals\":{\"secretsmanager:resource/AllowRotationLambdaArn\":\"arn:aws:lambda:eu-west-1:353833416626:function:agrovestoinfradeploymentagxdbRotationSingleUser096353C8\"}},\"Effect\":\"Allow\",\"Resource\":\"arn:aws:secretsmanager:eu-west-1:353833416626:secret:*\"},{\"Action\":[\"secretsmanager:GetRandomPassword\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole", "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"]
  max_session_duration = "3600"
  name                 = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-DTg5g94z5aY6"
  path                 = "/"

  tags = {
    Name                             = "agxdb"
    SecretsManagerLambda             = "Rotation"
    "lambda:createdBy"               = "SAM"
    "serverlessrepo:applicationId"   = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSSQLServerRotationSingleUser"
    "serverlessrepo:semanticVersion" = "1.1.618"
  }

  tags_all = {
    Name                             = "agxdb"
    SecretsManagerLambda             = "Rotation"
    "lambda:createdBy"               = "SAM"
    "serverlessrepo:applicationId"   = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSSQLServerRotationSingleUser"
    "serverlessrepo:semanticVersion" = "1.1.618"
  }
}

resource "aws_iam_role" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-EXyHA0Ipenan" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "SecretsManagerRDSSQLServerRotationSingleUserRolePolicy0"
    policy = "{\"Statement\":[{\"Action\":[\"ec2:CreateNetworkInterface\",\"ec2:DeleteNetworkInterface\",\"ec2:DescribeNetworkInterfaces\",\"ec2:DetachNetworkInterface\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
  }

  inline_policy {
    name   = "SecretsManagerRDSSQLServerRotationSingleUserRolePolicy1"
    policy = "{\"Statement\":[{\"Action\":[\"secretsmanager:DescribeSecret\",\"secretsmanager:GetSecretValue\",\"secretsmanager:PutSecretValue\",\"secretsmanager:UpdateSecretVersionStage\"],\"Condition\":{\"StringEquals\":{\"secretsmanager:resource/AllowRotationLambdaArn\":\"arn:aws:lambda:eu-west-1:353833416626:function:agrovestoinfradeploymentnomaosdbRotationSingleUser77906076\"}},\"Effect\":\"Allow\",\"Resource\":\"arn:aws:secretsmanager:eu-west-1:353833416626:secret:*\"},{\"Action\":[\"secretsmanager:GetRandomPassword\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole", "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"]
  max_session_duration = "3600"
  name                 = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-EXyHA0Ipenan"
  path                 = "/"

  tags = {
    Name                             = "nomaosdb"
    SecretsManagerLambda             = "Rotation"
    "lambda:createdBy"               = "SAM"
    "serverlessrepo:applicationId"   = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSSQLServerRotationSingleUser"
    "serverlessrepo:semanticVersion" = "1.1.618"
  }

  tags_all = {
    Name                             = "nomaosdb"
    SecretsManagerLambda             = "Rotation"
    "lambda:createdBy"               = "SAM"
    "serverlessrepo:applicationId"   = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSSQLServerRotationSingleUser"
    "serverlessrepo:semanticVersion" = "1.1.618"
  }
}

resource "aws_iam_role" "tfer--amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCustom-ejNMfppltfPg" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "AmplifyBranchLinkerCustomResourceProviderframeworkonEventServiceRoleDefaultPolicy38AAE412"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":\"lambda:InvokeFunction\",\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:lambda:eu-central-1:353833416626:function:amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCusto-TIbEIMcYF5NU\",\"arn:aws:lambda:eu-central-1:353833416626:function:amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCusto-TIbEIMcYF5NU:*\"]},{\"Action\":\"lambda:GetFunction\",\"Effect\":\"Allow\",\"Resource\":\"arn:aws:lambda:eu-central-1:353833416626:function:amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCusto-TIbEIMcYF5NU\"}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
  max_session_duration = "3600"
  name                 = "amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCustom-ejNMfppltfPg"
  path                 = "/"

  tags = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    created-by                = "amplify"
  }

  tags_all = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    created-by                = "amplify"
  }
}

resource "aws_iam_role" "tfer--amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCustom-fzp661Q35Odb" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "AmplifyBranchLinkerCustomResourceLambdaServiceRoleDefaultPolicy86099CA1"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"amplify:GetBranch\",\"amplify:UpdateBranch\"],\"Effect\":\"Allow\",\"Resource\":\"arn:aws:amplify:*:*:apps/d3setdk1gwy695/branches/main\"}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
  max_session_duration = "3600"
  name                 = "amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCustom-fzp661Q35Odb"
  path                 = "/"

  tags = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    created-by                = "amplify"
  }

  tags_all = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    created-by                = "amplify"
  }
}

resource "aws_iam_role" "tfer--amplify-d3setdk1gwy695-ma-AmplifyManagedTableIsComp-rcS8Djx2OFrP" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "CreateUpdateDeleteTablesPolicy"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"dynamodb:CreateTable\",\"dynamodb:UpdateTable\",\"dynamodb:DeleteTable\",\"dynamodb:DescribeTable\",\"dynamodb:DescribeContinuousBackups\",\"dynamodb:DescribeTimeToLive\",\"dynamodb:UpdateContinuousBackups\",\"dynamodb:UpdateTimeToLive\",\"dynamodb:TagResource\",\"dynamodb:UntagResource\",\"dynamodb:ListTagsOfResource\"],\"Effect\":\"Allow\",\"Resource\":\"arn:aws:dynamodb:eu-central-1:353833416626:table/*-beg42uuyereqjerfalxrk72nmq-NONE\"},{\"Action\":\"lambda:ListTags\",\"Effect\":\"Allow\",\"Resource\":\"arn:aws:lambda:eu-central-1:353833416626:function:*TableManager*\"}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
  max_session_duration = "3600"
  name                 = "amplify-d3setdk1gwy695-ma-AmplifyManagedTableIsComp-rcS8Djx2OFrP"
  path                 = "/"

  tags = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyData"
    created-by                = "amplify"
  }

  tags_all = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyData"
    created-by                = "amplify"
  }
}

resource "aws_iam_role" "tfer--amplify-d3setdk1gwy695-ma-AmplifyManagedTableOnEven-SnL0p2y5qusS" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "AmplifyManagedTableOnEventRoleDefaultPolicyF6DABCB6"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":\"states:StartExecution\",\"Effect\":\"Allow\",\"Resource\":\"arn:aws:states:eu-central-1:353833416626:stateMachine:AmplifyTableWaiterStateMachine060600BC-QZV6ZLw5IuQN\"}]}"
  }

  inline_policy {
    name   = "CreateUpdateDeleteTablesPolicy"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"dynamodb:CreateTable\",\"dynamodb:UpdateTable\",\"dynamodb:DeleteTable\",\"dynamodb:DescribeTable\",\"dynamodb:DescribeContinuousBackups\",\"dynamodb:DescribeTimeToLive\",\"dynamodb:UpdateContinuousBackups\",\"dynamodb:UpdateTimeToLive\",\"dynamodb:TagResource\",\"dynamodb:UntagResource\",\"dynamodb:ListTagsOfResource\"],\"Effect\":\"Allow\",\"Resource\":\"arn:aws:dynamodb:eu-central-1:353833416626:table/*-beg42uuyereqjerfalxrk72nmq-NONE\"},{\"Action\":\"lambda:ListTags\",\"Effect\":\"Allow\",\"Resource\":\"arn:aws:lambda:eu-central-1:353833416626:function:*TableManager*\"}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
  max_session_duration = "3600"
  name                 = "amplify-d3setdk1gwy695-ma-AmplifyManagedTableOnEven-SnL0p2y5qusS"
  path                 = "/"

  tags = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyData"
    created-by                = "amplify"
  }

  tags_all = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyData"
    created-by                = "amplify"
  }
}

resource "aws_iam_role" "tfer--amplify-d3setdk1gwy695-ma-AmplifyTableWaiterStateMa-I3G2jMlyNE9g" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "states.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "AmplifyTableWaiterStateMachineRoleDefaultPolicy89F3836A"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":\"lambda:InvokeFunction\",\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:lambda:eu-central-1:353833416626:function:amplify-d3setdk1gwy695-ma-TableManagerCustomProvid-uhpMyup4WP7D\",\"arn:aws:lambda:eu-central-1:353833416626:function:amplify-d3setdk1gwy695-ma-TableManagerCustomProvid-uhpMyup4WP7D:*\"]}]}"
  }

  max_session_duration = "3600"
  name                 = "amplify-d3setdk1gwy695-ma-AmplifyTableWaiterStateMa-I3G2jMlyNE9g"
  path                 = "/"

  tags = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyData"
    created-by                = "amplify"
  }

  tags_all = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyData"
    created-by                = "amplify"
  }
}

resource "aws_iam_role" "tfer--amplify-d3setdk1gwy695-ma-CustomCDKBucketDeployment-pZMgmQWVhiQn" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "CustomCDKBucketDeployment8693BB64968944B69AAFB0CC9EB8756C1536MiBServiceRoleDefaultPolicyFF1C635B"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"s3:GetObject*\",\"s3:GetBucket*\",\"s3:List*\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1\",\"arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1/*\"]},{\"Action\":[\"s3:GetObject*\",\"s3:GetBucket*\",\"s3:List*\",\"s3:DeleteObject*\",\"s3:PutObject\",\"s3:PutObjectLegalHold\",\"s3:PutObjectRetention\",\"s3:PutObjectTagging\",\"s3:PutObjectVersionTagging\",\"s3:Abort*\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-amplifydataamplifycodege-mubkzp2mfehx\",\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-amplifydataamplifycodege-mubkzp2mfehx/*\"]},{\"Action\":[\"s3:GetObject*\",\"s3:GetBucket*\",\"s3:List*\",\"s3:DeleteObject*\",\"s3:PutObject\",\"s3:PutObjectLegalHold\",\"s3:PutObjectRetention\",\"s3:PutObjectTagging\",\"s3:PutObjectVersionTagging\",\"s3:Abort*\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-modelintrospectionschema-xv7wrateaqhd\",\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-modelintrospectionschema-xv7wrateaqhd/*\"]}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
  max_session_duration = "3600"
  name                 = "amplify-d3setdk1gwy695-ma-CustomCDKBucketDeployment-pZMgmQWVhiQn"
  path                 = "/"

  tags = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    created-by                = "amplify"
  }

  tags_all = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    created-by                = "amplify"
  }
}

resource "aws_iam_role" "tfer--amplify-d3setdk1gwy695-ma-CustomS3AutoDeleteObjects-BK3zRlUFMp70" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
  max_session_duration = "3600"
  name                 = "amplify-d3setdk1gwy695-ma-CustomS3AutoDeleteObjects-BK3zRlUFMp70"
  path                 = "/"

  tags = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    created-by                = "amplify"
  }

  tags_all = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    created-by                = "amplify"
  }
}

resource "aws_iam_role" "tfer--amplify-d3setdk1gwy695-ma-CustomS3AutoDeleteObjects-izjLHpD4ISHR" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
  max_session_duration = "3600"
  name                 = "amplify-d3setdk1gwy695-ma-CustomS3AutoDeleteObjects-izjLHpD4ISHR"
  path                 = "/"

  tags = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    created-by                = "amplify"
  }

  tags_all = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    created-by                = "amplify"
  }
}

resource "aws_iam_role" "tfer--amplify-d3setdk1gwy695-ma-amplifyAuthADMINSGroupRol-juVbDCIYcV7g" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "authenticated"
        },
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "eu-central-1:a5190588-09c7-4827-850c-5f37ce00183d"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  max_session_duration = "3600"
  name                 = "amplify-d3setdk1gwy695-ma-amplifyAuthADMINSGroupRol-juVbDCIYcV7g"
  path                 = "/"

  tags = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyAuth"
    created-by                = "amplify"
  }

  tags_all = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyAuth"
    created-by                = "amplify"
  }
}

resource "aws_iam_role" "tfer--amplify-d3setdk1gwy695-ma-amplifyAuthauthenticatedU-9bTF5ojNgNm7" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "authenticated"
        },
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "eu-central-1:a5190588-09c7-4827-850c-5f37ce00183d"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "amplifyd3setdk1gwy695mainbranch467367b8b9storageAccess4BE0C7C0F"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":\"s3:GetObject\",\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/media/*\",\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/admin/*\"]},{\"Action\":\"s3:ListBucket\",\"Condition\":{\"StringLike\":{\"s3:prefix\":[\"media/*\",\"media/\",\"admin/*\",\"admin/\"]}},\"Effect\":\"Allow\",\"Resource\":\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5\"},{\"Action\":\"s3:PutObject\",\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/media/*\",\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/admin/*\"]},{\"Action\":\"s3:DeleteObject\",\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/media/*\",\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/admin/*\"]}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::353833416626:policy/amplify-d3setdk1gwy695-main-branch-467367b8b9-data7552DF31-13E3RJPY8AFZP-amplifyDataAuthRolePolicy01567A5654-kJ3IQgNtXlXZ"]
  max_session_duration = "3600"
  name                 = "amplify-d3setdk1gwy695-ma-amplifyAuthauthenticatedU-9bTF5ojNgNm7"
  path                 = "/"

  tags = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyAuth"
    created-by                = "amplify"
  }

  tags_all = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyAuth"
    created-by                = "amplify"
  }
}

resource "aws_iam_role" "tfer--amplify-d3setdk1gwy695-ma-amplifyAuthunauthenticate-PeKmwwLSiQEo" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "unauthenticated"
        },
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "eu-central-1:a5190588-09c7-4827-850c-5f37ce00183d"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "amplifyd3setdk1gwy695mainbranch467367b8b9storageAccess395743666"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":\"s3:GetObject\",\"Effect\":\"Allow\",\"Resource\":\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/media/*\"},{\"Action\":\"s3:ListBucket\",\"Condition\":{\"StringLike\":{\"s3:prefix\":[\"media/*\",\"media/\"]}},\"Effect\":\"Allow\",\"Resource\":\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5\"},{\"Action\":\"s3:PutObject\",\"Effect\":\"Allow\",\"Resource\":\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/media/*\"},{\"Action\":\"s3:PutObject\",\"Effect\":\"Deny\",\"Resource\":[\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/media/processed/*\",\"arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/media/thumbnails/*\"]}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::353833416626:policy/amplify-d3setdk1gwy695-main-branch-467367b8b9-data7552DF31-13E3RJPY8AFZP-amplifyDataUnauthRolePolicy01355B9DCF-HIvjT1HkH1Fp"]
  max_session_duration = "3600"
  name                 = "amplify-d3setdk1gwy695-ma-amplifyAuthunauthenticate-PeKmwwLSiQEo"
  path                 = "/"

  tags = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyAuth"
    created-by                = "amplify"
  }

  tags_all = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "amplifyAuth"
    created-by                = "amplify"
  }
}

resource "aws_iam_role" "tfer--amplify-d3setdk1gwy695-ma-presignuplambdaServiceRol-3sfnt65dFkcU" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
  max_session_duration = "3600"
  name                 = "amplify-d3setdk1gwy695-ma-presignuplambdaServiceRol-3sfnt65dFkcU"
  path                 = "/"

  tags = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "pre-sign-up"
    created-by                = "amplify"
  }

  tags_all = {
    "amplify:app-id"          = "d3setdk1gwy695"
    "amplify:branch-name"     = "main"
    "amplify:deployment-type" = "branch"
    "amplify:friendly-name"   = "pre-sign-up"
    created-by                = "amplify"
  }
}

resource "aws_iam_role" "tfer--cdk-hnb659fds-cfn-exec-role-353833416626-eu-central-1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudformation.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  max_session_duration = "3600"
  name                 = "cdk-hnb659fds-cfn-exec-role-353833416626-eu-central-1"
  path                 = "/"
}

resource "aws_iam_role" "tfer--cdk-hnb659fds-cfn-exec-role-353833416626-eu-west-1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudformation.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  max_session_duration = "3600"
  name                 = "cdk-hnb659fds-cfn-exec-role-353833416626-eu-west-1"
  path                 = "/"
}

resource "aws_iam_role" "tfer--cdk-hnb659fds-deploy-role-353833416626-eu-central-1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Condition": {
        "Null": {
          "sts:ExternalId": "true"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    },
    {
      "Action": "sts:TagSession",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    }
  ],
  "Version": "2008-10-17"
}
POLICY

  inline_policy {
    name   = "default"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"cloudformation:CreateChangeSet\",\"cloudformation:DeleteChangeSet\",\"cloudformation:ExecuteChangeSet\",\"cloudformation:CreateStack\",\"cloudformation:UpdateStack\",\"cloudformation:RollbackStack\",\"cloudformation:ContinueUpdateRollback\"],\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"DeployPermissions\"},{\"Action\":[\"s3:GetObject*\",\"s3:GetBucket*\",\"s3:List*\",\"s3:Abort*\",\"s3:DeleteObject*\",\"s3:PutObject*\"],\"Condition\":{\"StringNotEquals\":{\"s3:ResourceAccount\":\"353833416626\"}},\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"PipelineCrossAccountArtifactsBucket\"},{\"Action\":[\"kms:Decrypt\",\"kms:DescribeKey\",\"kms:Encrypt\",\"kms:ReEncrypt*\",\"kms:GenerateDataKey*\"],\"Condition\":{\"StringEquals\":{\"kms:ViaService\":\"s3.eu-central-1.amazonaws.com\"}},\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"PipelineCrossAccountArtifactsKey\"},{\"Action\":\"iam:PassRole\",\"Effect\":\"Allow\",\"Resource\":\"arn:aws:iam::353833416626:role/cdk-hnb659fds-cfn-exec-role-353833416626-eu-central-1\"},{\"Action\":[\"cloudformation:DeleteStack\",\"cloudformation:UpdateTerminationProtection\",\"sts:GetCallerIdentity\"],\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"CliPermissions\"},{\"Action\":[\"s3:GetObject*\",\"s3:GetBucket*\",\"s3:List*\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1\",\"arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1/*\"],\"Sid\":\"CliStagingBucket\"},{\"Action\":[\"ssm:GetParameter\",\"ssm:GetParameters\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:ssm:eu-central-1:353833416626:parameter/cdk-bootstrap/hnb659fds/version\"],\"Sid\":\"ReadVersion\"},{\"Action\":[\"cloudformation:CreateStackRefactor\",\"cloudformation:ExecuteStackRefactor\"],\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"Refactor\"}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AWSCloudFormationReadOnlyAccess"]
  max_session_duration = "3600"
  name                 = "cdk-hnb659fds-deploy-role-353833416626-eu-central-1"
  path                 = "/"

  tags = {
    "aws-cdk:bootstrap-role" = "deploy"
  }

  tags_all = {
    "aws-cdk:bootstrap-role" = "deploy"
  }
}

resource "aws_iam_role" "tfer--cdk-hnb659fds-deploy-role-353833416626-eu-west-1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Condition": {
        "Null": {
          "sts:ExternalId": "true"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    },
    {
      "Action": "sts:TagSession",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    }
  ],
  "Version": "2008-10-17"
}
POLICY

  inline_policy {
    name   = "default"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"cloudformation:CreateChangeSet\",\"cloudformation:DeleteChangeSet\",\"cloudformation:DescribeChangeSet\",\"cloudformation:DescribeStacks\",\"cloudformation:ExecuteChangeSet\",\"cloudformation:CreateStack\",\"cloudformation:UpdateStack\",\"cloudformation:RollbackStack\",\"cloudformation:ContinueUpdateRollback\"],\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"CloudFormationPermissions\"},{\"Action\":[\"s3:GetObject*\",\"s3:GetBucket*\",\"s3:List*\",\"s3:Abort*\",\"s3:DeleteObject*\",\"s3:PutObject*\"],\"Condition\":{\"StringNotEquals\":{\"s3:ResourceAccount\":\"353833416626\"}},\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"PipelineCrossAccountArtifactsBucket\"},{\"Action\":[\"kms:Decrypt\",\"kms:DescribeKey\",\"kms:Encrypt\",\"kms:ReEncrypt*\",\"kms:GenerateDataKey*\"],\"Condition\":{\"StringEquals\":{\"kms:ViaService\":\"s3.eu-west-1.amazonaws.com\"}},\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"PipelineCrossAccountArtifactsKey\"},{\"Action\":\"iam:PassRole\",\"Effect\":\"Allow\",\"Resource\":\"arn:aws:iam::353833416626:role/cdk-hnb659fds-cfn-exec-role-353833416626-eu-west-1\"},{\"Action\":[\"cloudformation:DescribeStackEvents\",\"cloudformation:GetTemplate\",\"cloudformation:DeleteStack\",\"cloudformation:UpdateTerminationProtection\",\"sts:GetCallerIdentity\",\"cloudformation:GetTemplateSummary\"],\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"CliPermissions\"},{\"Action\":[\"s3:GetObject*\",\"s3:GetBucket*\",\"s3:List*\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-west-1\",\"arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-west-1/*\"],\"Sid\":\"CliStagingBucket\"},{\"Action\":[\"ssm:GetParameter\",\"ssm:GetParameters\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:ssm:eu-west-1:353833416626:parameter/cdk-bootstrap/hnb659fds/version\"],\"Sid\":\"ReadVersion\"},{\"Action\":[\"cloudformation:CreateStackRefactor\",\"cloudformation:DescribeStackRefactor\",\"cloudformation:ExecuteStackRefactor\",\"cloudformation:ListStackRefactorActions\",\"cloudformation:ListStackRefactors\",\"cloudformation:ListStacks\"],\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"Refactor\"}]}"
  }

  max_session_duration = "3600"
  name                 = "cdk-hnb659fds-deploy-role-353833416626-eu-west-1"
  path                 = "/"

  tags = {
    "aws-cdk:bootstrap-role" = "deploy"
  }

  tags_all = {
    "aws-cdk:bootstrap-role" = "deploy"
  }
}

resource "aws_iam_role" "tfer--cdk-hnb659fds-file-publishing-role-353833416626-eu-central-1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Condition": {
        "Null": {
          "sts:ExternalId": "true"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    },
    {
      "Action": "sts:TagSession",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    }
  ],
  "Version": "2008-10-17"
}
POLICY

  inline_policy {
    name   = "cdk-hnb659fds-file-publishing-role-default-policy-353833416626-eu-central-1"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"s3:GetObject*\",\"s3:GetBucket*\",\"s3:GetEncryptionConfiguration\",\"s3:List*\",\"s3:DeleteObject*\",\"s3:PutObject*\",\"s3:Abort*\"],\"Condition\":{\"StringEquals\":{\"aws:ResourceAccount\":[\"353833416626\"]}},\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1\",\"arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1/*\"]},{\"Action\":[\"kms:Decrypt\",\"kms:DescribeKey\",\"kms:Encrypt\",\"kms:ReEncrypt*\",\"kms:GenerateDataKey*\"],\"Effect\":\"Allow\",\"Resource\":\"arn:aws:kms:eu-central-1:353833416626:key/AWS_MANAGED_KEY\"}]}"
  }

  max_session_duration = "3600"
  name                 = "cdk-hnb659fds-file-publishing-role-353833416626-eu-central-1"
  path                 = "/"

  tags = {
    "aws-cdk:bootstrap-role" = "file-publishing"
  }

  tags_all = {
    "aws-cdk:bootstrap-role" = "file-publishing"
  }
}

resource "aws_iam_role" "tfer--cdk-hnb659fds-file-publishing-role-353833416626-eu-west-1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Condition": {
        "Null": {
          "sts:ExternalId": "true"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    },
    {
      "Action": "sts:TagSession",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    }
  ],
  "Version": "2008-10-17"
}
POLICY

  inline_policy {
    name   = "cdk-hnb659fds-file-publishing-role-default-policy-353833416626-eu-west-1"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"s3:GetObject*\",\"s3:GetBucket*\",\"s3:GetEncryptionConfiguration\",\"s3:List*\",\"s3:DeleteObject*\",\"s3:PutObject*\",\"s3:Abort*\"],\"Condition\":{\"StringEquals\":{\"aws:ResourceAccount\":[\"353833416626\"]}},\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-west-1\",\"arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-west-1/*\"]},{\"Action\":[\"kms:Decrypt\",\"kms:DescribeKey\",\"kms:Encrypt\",\"kms:ReEncrypt*\",\"kms:GenerateDataKey*\"],\"Effect\":\"Allow\",\"Resource\":\"arn:aws:kms:eu-west-1:353833416626:key/AWS_MANAGED_KEY\"}]}"
  }

  max_session_duration = "3600"
  name                 = "cdk-hnb659fds-file-publishing-role-353833416626-eu-west-1"
  path                 = "/"

  tags = {
    "aws-cdk:bootstrap-role" = "file-publishing"
  }

  tags_all = {
    "aws-cdk:bootstrap-role" = "file-publishing"
  }
}

resource "aws_iam_role" "tfer--cdk-hnb659fds-image-publishing-role-353833416626-eu-central-1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Condition": {
        "Null": {
          "sts:ExternalId": "true"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    },
    {
      "Action": "sts:TagSession",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    }
  ],
  "Version": "2008-10-17"
}
POLICY

  inline_policy {
    name   = "cdk-hnb659fds-image-publishing-role-default-policy-353833416626-eu-central-1"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"ecr:PutImage\",\"ecr:InitiateLayerUpload\",\"ecr:UploadLayerPart\",\"ecr:CompleteLayerUpload\",\"ecr:BatchCheckLayerAvailability\",\"ecr:DescribeRepositories\",\"ecr:DescribeImages\",\"ecr:BatchGetImage\",\"ecr:GetDownloadUrlForLayer\"],\"Effect\":\"Allow\",\"Resource\":\"arn:aws:ecr:eu-central-1:353833416626:repository/cdk-hnb659fds-container-assets-353833416626-eu-central-1\"},{\"Action\":[\"ecr:GetAuthorizationToken\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
  }

  max_session_duration = "3600"
  name                 = "cdk-hnb659fds-image-publishing-role-353833416626-eu-central-1"
  path                 = "/"

  tags = {
    "aws-cdk:bootstrap-role" = "image-publishing"
  }

  tags_all = {
    "aws-cdk:bootstrap-role" = "image-publishing"
  }
}

resource "aws_iam_role" "tfer--cdk-hnb659fds-image-publishing-role-353833416626-eu-west-1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Condition": {
        "Null": {
          "sts:ExternalId": "true"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    },
    {
      "Action": "sts:TagSession",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    }
  ],
  "Version": "2008-10-17"
}
POLICY

  inline_policy {
    name   = "cdk-hnb659fds-image-publishing-role-default-policy-353833416626-eu-west-1"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"ecr:PutImage\",\"ecr:InitiateLayerUpload\",\"ecr:UploadLayerPart\",\"ecr:CompleteLayerUpload\",\"ecr:BatchCheckLayerAvailability\",\"ecr:DescribeRepositories\",\"ecr:DescribeImages\",\"ecr:BatchGetImage\",\"ecr:GetDownloadUrlForLayer\"],\"Effect\":\"Allow\",\"Resource\":\"arn:aws:ecr:eu-west-1:353833416626:repository/cdk-hnb659fds-container-assets-353833416626-eu-west-1\"},{\"Action\":[\"ecr:GetAuthorizationToken\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
  }

  max_session_duration = "3600"
  name                 = "cdk-hnb659fds-image-publishing-role-353833416626-eu-west-1"
  path                 = "/"

  tags = {
    "aws-cdk:bootstrap-role" = "image-publishing"
  }

  tags_all = {
    "aws-cdk:bootstrap-role" = "image-publishing"
  }
}

resource "aws_iam_role" "tfer--cdk-hnb659fds-lookup-role-353833416626-eu-central-1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Condition": {
        "Null": {
          "sts:ExternalId": "true"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    },
    {
      "Action": "sts:TagSession",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    }
  ],
  "Version": "2008-10-17"
}
POLICY

  inline_policy {
    name   = "LookupRolePolicy"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"kms:Decrypt\"],\"Effect\":\"Deny\",\"Resource\":\"*\",\"Sid\":\"DontReadSecrets\"}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  max_session_duration = "3600"
  name                 = "cdk-hnb659fds-lookup-role-353833416626-eu-central-1"
  path                 = "/"

  tags = {
    "aws-cdk:bootstrap-role" = "lookup"
  }

  tags_all = {
    "aws-cdk:bootstrap-role" = "lookup"
  }
}

resource "aws_iam_role" "tfer--cdk-hnb659fds-lookup-role-353833416626-eu-west-1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Condition": {
        "Null": {
          "sts:ExternalId": "true"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    },
    {
      "Action": "sts:TagSession",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::353833416626:root"
      }
    }
  ],
  "Version": "2008-10-17"
}
POLICY

  inline_policy {
    name   = "LookupRolePolicy"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"kms:Decrypt\"],\"Effect\":\"Deny\",\"Resource\":\"*\",\"Sid\":\"DontReadSecrets\"}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  max_session_duration = "3600"
  name                 = "cdk-hnb659fds-lookup-role-353833416626-eu-west-1"
  path                 = "/"

  tags = {
    "aws-cdk:bootstrap-role" = "lookup"
  }

  tags_all = {
    "aws-cdk:bootstrap-role" = "lookup"
  }
}

resource "aws_iam_role" "tfer--ec2_role" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AmazonSSMFullAccess", "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"]
  max_session_duration = "3600"
  name                 = "ec2_role"
  path                 = "/"
}

resource "aws_iam_role" "tfer--ec2_role-12c63a" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"]
  max_session_duration = "3600"
  name                 = "ec2_role-12c63a"
  path                 = "/"
}

resource "aws_iam_role" "tfer--nomaos-amplify" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "amplify.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description = "Allows Amplify Backend Deployment to access AWS resources on your behalf."

  inline_policy {
    name   = "amplifyaccess"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":\"sts:AssumeRole\",\"Effect\":\"Allow\",\"Resource\":\"arn:aws:iam::*:role/cdk-hnb659fds-*\"}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess-Amplify"]
  max_session_duration = "3600"
  name                 = "nomaos-amplify"
  path                 = "/"
}

resource "aws_iam_role" "tfer--nomaos-bootstrap-dev-deploy" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:Agrovesto/infrastructure:environment:dev:ref:refs/heads/dev:event_name:push:workflow_ref:Agrovesto/infrastructure/.github/workflows/infrastructure.yml@refs/heads/dev"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::353833416626:oidc-provider/token.actions.githubusercontent.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "BoundedWorkloadIAM"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"iam:GetRole\",\"iam:GetRolePolicy\",\"iam:ListRolePolicies\",\"iam:ListAttachedRolePolicies\",\"iam:GetInstanceProfile\",\"iam:GetPolicy\",\"iam:GetPolicyVersion\",\"iam:ListInstanceProfilesForRole\",\"iam:ListRoleTags\",\"iam:ListInstanceProfileTags\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:iam::353833416626:role/nomaos-dev-*\",\"arn:aws:iam::353833416626:role/aws-service-role/*\",\"arn:aws:iam::353833416626:instance-profile/nomaos-dev-*\",\"arn:aws:iam::353833416626:policy/nomaos-bootstrap-dev-workload-boundary\",\"arn:aws:iam::aws:policy/*\"],\"Sid\":\"IAMReadOnly\"},{\"Action\":\"iam:CreateRole\",\"Condition\":{\"StringEquals\":{\"iam:PermissionsBoundary\":\"arn:aws:iam::353833416626:policy/nomaos-bootstrap-dev-workload-boundary\"}},\"Effect\":\"Allow\",\"Resource\":\"arn:aws:iam::353833416626:role/nomaos-dev-*\",\"Sid\":\"CreateOnlyBoundedRoles\"},{\"Action\":[\"iam:DeleteRole\",\"iam:UpdateRole\",\"iam:UpdateRoleDescription\",\"iam:UpdateAssumeRolePolicy\",\"iam:PutRolePolicy\",\"iam:DeleteRolePolicy\",\"iam:TagRole\",\"iam:UntagRole\",\"iam:DetachRolePolicy\"],\"Effect\":\"Allow\",\"Resource\":\"arn:aws:iam::353833416626:role/nomaos-dev-*\",\"Sid\":\"ManageOnlyWorkloadRoles\"},{\"Action\":\"iam:AttachRolePolicy\",\"Condition\":{\"ArnEquals\":{\"iam:PolicyARN\":[\"arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore\",\"arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup\",\"arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole\"]}},\"Effect\":\"Allow\",\"Resource\":\"arn:aws:iam::353833416626:role/nomaos-dev-*\",\"Sid\":\"ApprovedAWSRuntimePoliciesOnly\"},{\"Action\":[\"iam:CreateInstanceProfile\",\"iam:DeleteInstanceProfile\",\"iam:AddRoleToInstanceProfile\",\"iam:RemoveRoleFromInstanceProfile\",\"iam:TagInstanceProfile\",\"iam:UntagInstanceProfile\"],\"Effect\":\"Allow\",\"Resource\":\"arn:aws:iam::353833416626:instance-profile/nomaos-dev-*\",\"Sid\":\"ManageWorkloadInstanceProfiles\"},{\"Action\":\"iam:PassRole\",\"Condition\":{\"StringEquals\":{\"iam:PassedToService\":[\"ec2.amazonaws.com\",\"ecs-tasks.amazonaws.com\",\"rds.amazonaws.com\",\"monitoring.rds.amazonaws.com\",\"backup.amazonaws.com\",\"vpc-flow-logs.amazonaws.com\",\"cloudtrail.amazonaws.com\",\"events.amazonaws.com\"]}},\"Effect\":\"Allow\",\"Resource\":\"arn:aws:iam::353833416626:role/nomaos-dev-*\",\"Sid\":\"PassOnlyWorkloadRolesToServices\"},{\"Action\":\"iam:CreateServiceLinkedRole\",\"Condition\":{\"StringEquals\":{\"iam:AWSServiceName\":[\"ecs.amazonaws.com\",\"ecs.application-autoscaling.amazonaws.com\",\"elasticloadbalancing.amazonaws.com\",\"rds.amazonaws.com\",\"backup.amazonaws.com\",\"guardduty.amazonaws.com\"]}},\"Effect\":\"Allow\",\"Resource\":\"arn:aws:iam::353833416626:role/aws-service-role/*\",\"Sid\":\"RequiredServiceLinkedRoles\"}]}"
  }

  inline_policy {
    name   = "ProvisionInfrastructureServices"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"ec2:*\",\"elasticloadbalancing:*\",\"ecs:*\",\"ecr:*\",\"rds:*\",\"application-autoscaling:*\",\"autoscaling:Describe*\",\"s3:*\",\"kms:*\",\"logs:*\",\"cloudwatch:*\",\"sns:*\",\"budgets:*\",\"backup:*\",\"events:*\",\"ssm:*\",\"secretsmanager:*\",\"acm:*\",\"route53:*\",\"amplify:*\",\"cloudtrail:*\",\"guardduty:*\"],\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"InfrastructureServices\"},{\"Action\":[\"s3:DeleteBucket\",\"s3:DeleteBucketPolicy\",\"s3:PutBucket*\",\"s3:PutEncryptionConfiguration\",\"s3:PutLifecycleConfiguration\",\"s3:PutReplicationConfiguration\",\"s3:PutAccelerateConfiguration\",\"s3:DeleteObjectVersion\"],\"Effect\":\"Deny\",\"Resource\":[\"arn:aws:s3:::nomaos-tfstate-353833416626-eu-west-1\",\"arn:aws:s3:::nomaos-tfstate-353833416626-eu-west-1/*\",\"arn:aws:s3:::nomaos-tfstate-logs-353833416626-eu-west-1\",\"arn:aws:s3:::nomaos-tfstate-logs-353833416626-eu-west-1/*\"],\"Sid\":\"ProtectBackendConfiguration\"},{\"Action\":\"s3:*\",\"Effect\":\"Deny\",\"Resource\":\"arn:aws:s3:::nomaos-tfstate-353833416626-eu-west-1/dev/bootstrap.tfstate*\",\"Sid\":\"ProtectBootstrapState\"},{\"Action\":\"s3:DeleteObject\",\"Effect\":\"Deny\",\"Resource\":\"arn:aws:s3:::nomaos-tfstate-353833416626-eu-west-1/dev/terraform.tfstate\",\"Sid\":\"DoNotDeleteEnvironmentState\"},{\"Effect\":\"Deny\",\"NotAction\":[\"kms:Decrypt\",\"kms:Encrypt\",\"kms:GenerateDataKey*\",\"kms:DescribeKey\"],\"Resource\":[\"arn:aws:kms:eu-west-1:353833416626:key/31f57b1f-cbde-4aa6-8c6e-18e129c80fb6\",\"arn:aws:kms:eu-west-1:353833416626:alias/nomaos-bootstrap-dev\"],\"Sid\":\"ProtectBackendKey\"}]}"
  }

  max_session_duration = "7200"
  name                 = "nomaos-bootstrap-dev-deploy"
  path                 = "/"

  tags = {
    Component   = "bootstrap"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Project     = "nomaos"
  }

  tags_all = {
    Component   = "bootstrap"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Project     = "nomaos"
  }
}

resource "aws_iam_role" "tfer--nomaos-dev-github-terraform" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:Agrovesto@101108012/*:ref:refs/heads/main",
            "repo:Agrovesto@101108012/*:ref:refs/heads/dev",
            "repo:Agrovesto@101108012/*:pull_request"
          ]
        }
      },
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::353833416626:oidc-provider/token.actions.githubusercontent.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  max_session_duration = "3600"
  name                 = "nomaos-dev-github-terraform"
  path                 = "/"

  tags = {
    Component  = "bootstrap"
    ManagedBy  = "terraform"
    Project    = "nomaos"
    Repository = "Agrovesto/ecs-prod-infra"
  }

  tags_all = {
    Component  = "bootstrap"
    ManagedBy  = "terraform"
    Project    = "nomaos"
    Repository = "Agrovesto/ecs-prod-infra"
  }
}

resource "aws_iam_role" "tfer--rds-monitoring-role" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "monitoring.rds.amazonaws.com"
      },
      "Sid": ""
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"]
  max_session_duration = "3600"
  name                 = "rds-monitoring-role"
  path                 = "/"
}

resource "aws_iam_role" "tfer--ssmrole" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Sid": "EC2AssumeRole"
    },
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "scheduler.amazonaws.com"
      },
      "Sid": "SchedulerAssumeRole"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description = "Allows EC2 instances to call AWS services like CloudWatch and Systems Manager on your behalf."

  inline_policy {
    name   = "iam"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"iam:GetRole\",\"iam:GetRolePolicy\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess", "arn:aws:iam::aws:policy/AmazonEventBridgeSchedulerFullAccess", "arn:aws:iam::aws:policy/AmazonS3FullAccess", "arn:aws:iam::aws:policy/AmazonSSMFullAccess", "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy", "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"]
  max_session_duration = "3600"
  name                 = "ssmrole"
  path                 = "/"
}

resource "aws_iam_role" "tfer--test-role-dfn63jmf" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::353833416626:policy/service-role/AWSLambdaBasicExecutionRole-11c81ffa-eaed-45b5-b356-bf24894d1193", "arn:aws:iam::353833416626:policy/service-role/AWSLambdaVPCAccessExecutionRole-6aa51a87-0e83-4869-be44-e074cad3bc76"]
  max_session_duration = "3600"
  name                 = "test-role-dfn63jmf"
  path                 = "/service-role/"
}
