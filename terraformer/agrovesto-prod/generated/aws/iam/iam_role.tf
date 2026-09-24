resource "aws_iam_role" "tfer--AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "221434544570"
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

  managed_policy_arns  = ["arn:aws:iam::221434544570:policy/service-role/AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8", "arn:aws:iam::221434544570:policy/service-role/CodePipeline-CodeConnections-eu-west-1-argovesto-api-v8", "arn:aws:iam::aws:policy/AmazonSSMFullAccess", "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess", "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"]
  max_session_duration = "3600"
  name                 = "AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8"
  path                 = "/service-role/"
}

resource "aws_iam_role" "tfer--AWSReservedSSO_AdministratorAccess_bf9552b39d2cb66a" {
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
        "Federated": "arn:aws:iam::221434544570:saml-provider/AWSSSO_8be077417073c75c_DO_NOT_DELETE"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  max_session_duration = "43200"
  name                 = "AWSReservedSSO_AdministratorAccess_bf9552b39d2cb66a"
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

  description          = "Allows Cost Optimization Hub to retrieve organization information and collect optimization-related data and metadata."
  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/CostOptimizationHubServiceRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForCostOptimizationHub"
  path                 = "/aws-service-role/cost-optimization-hub.bcm.amazonaws.com/"
}

resource "aws_iam_role" "tfer--AWSServiceRoleForDMSServerless" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "dms.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "Service Linked Role created for AWS DMS to perform DMS actions on your behalf."
  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/AWSDMSServerlessServiceRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForDMSServerless"
  path                 = "/aws-service-role/dms.amazonaws.com/"
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

resource "aws_iam_role" "tfer--AWSServiceRoleForGlobalAccelerator" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "globalaccelerator.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "Allows Global Accelerator to call AWS services on customer's behalf"
  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/AWSGlobalAcceleratorSLRPolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForGlobalAccelerator"
  path                 = "/aws-service-role/globalaccelerator.amazonaws.com/"
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

resource "aws_iam_role" "tfer--AWSServiceRoleForSMSVoice" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "sms-voice.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/aws-service-role/SMSVoiceServiceRolePolicy"]
  max_session_duration = "3600"
  name                 = "AWSServiceRoleForSMSVoice"
  path                 = "/aws-service-role/sms-voice.amazonaws.com/"
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

resource "aws_iam_role" "tfer--AWSSystemsManagerDefaultEC2InstanceManagementRole" {
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

  description          = "AWS Systems Manager Default EC2 Instance Management Role"
  managed_policy_arns  = ["arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"]
  max_session_duration = "3600"
  name                 = "AWSSystemsManagerDefaultEC2InstanceManagementRole"
  path                 = "/service-role/"
}

resource "aws_iam_role" "tfer--AmplifySSRLoggingRole-227acf59-5d64-413b-b600-1a52d75bec84" {
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
  managed_policy_arns  = ["arn:aws:iam::221434544570:policy/service-role/AmplifySSRLoggingPolicy-227acf59-5d64-413b-b600-1a52d75bec84", "arn:aws:iam::aws:policy/AdministratorAccess-Amplify", "arn:aws:iam::aws:policy/service-role/AmplifyBackendDeployFullAccess"]
  max_session_duration = "3600"
  name                 = "AmplifySSRLoggingRole-227acf59-5d64-413b-b600-1a52d75bec84"
  path                 = "/service-role/"
}

resource "aws_iam_role" "tfer--CloudWatchAgentServerPolicy" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Sid": ""
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "Allows EC2 instances to call AWS services like CloudWatch and Systems Manager on your behalf."
  managed_policy_arns  = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", "arn:aws:iam::aws:policy/CloudWatchAgentAdminPolicy", "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
  max_session_duration = "3600"
  name                 = "CloudWatchAgentServerPolicy"
  path                 = "/"
}

resource "aws_iam_role" "tfer--CodeBuildDeploymentRole" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  max_session_duration = "3600"
  name                 = "CodeBuildDeploymentRole"
  path                 = "/"
}

resource "aws_iam_role" "tfer--CodeBuildServiceRole" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  inline_policy {
    name   = "DevAssumeCodeBuildDeploymentRole"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":\"sts:AssumeRole\",\"Effect\":\"Allow\",\"Resource\":\"arn:aws:iam::*:role/CodeBuildDeploymentRole\"}]}"
  }

  inline_policy {
    name   = "DevCodeBuildLogsPolicy"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"logs:DescribeLogGroups\",\"logs:GetLogEvents\",\"logs:DeleteLogGroup\",\"logs:CreateLogGroup\",\"logs:CreateLogStream\",\"logs:DeleteLogStream\",\"logs:PutLogEvents\",\"logs:DescribeLogStreams\",\"s3:GetObject\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:logs:*:*:log-group:/aws/codebuild/*\",\"arn:aws:logs:*:*:log-group:/aws/codebuild/*:log-stream:*\",\"arn:aws:s3:::*\"]}]}"
  }

  max_session_duration = "3600"
  name                 = "CodeBuildServiceRole"
  path                 = "/"
}

resource "aws_iam_role" "tfer--DMSSecretManagerAccessRole-agxdb2DBcredentials" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "221434544570"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "dms-data-migrations.amazonaws.com",
          "dms.eu-west-1.amazonaws.com",
          "dms.amazonaws.com"
        ]
      },
      "Sid": "AWSDMSSecretsManagerPolicyTemplate"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "Used by AWS DMS to access AWS Secrets Manager for managing database credentials securely."
  managed_policy_arns  = ["arn:aws:iam::221434544570:policy/service-role/DMSSecretManagerPolicy-DMSSecretManagerAccessRole-agxdb2DBcredentials"]
  max_session_duration = "3600"
  name                 = "DMSSecretManagerAccessRole-agxdb2DBcredentials"
  path                 = "/service-role/"
}

resource "aws_iam_role" "tfer--DMSSecretManagerAccessRole-nomaosDBcredentials" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "221434544570"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "dms.eu-west-1.amazonaws.com",
          "dms.amazonaws.com",
          "dms-data-migrations.amazonaws.com"
        ]
      },
      "Sid": "AWSDMSSecretsManagerPolicyTemplate"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "Used by AWS DMS to access AWS Secrets Manager for managing database credentials securely."
  managed_policy_arns  = ["arn:aws:iam::221434544570:policy/service-role/DMSSecretManagerPolicy-DMSSecretManagerAccessRole-nomaosDBcredentials"]
  max_session_duration = "3600"
  name                 = "DMSSecretManagerAccessRole-nomaosDBcredentials"
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
          "token.actions.githubusercontent.com:sub": [
            "repo:agrovesto/*",
            "repo:agrovesto/*"
          ]
        }
      },
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::221434544570:oidc-provider/token.actions.githubusercontent.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AWSCloudFormationFullAccess", "arn:aws:iam::aws:policy/AmazonEC2FullAccess", "arn:aws:iam::aws:policy/AmazonRDSFullAccess", "arn:aws:iam::aws:policy/AmazonS3FullAccess", "arn:aws:iam::aws:policy/AmazonSSMFullAccess", "arn:aws:iam::aws:policy/IAMFullAccess", "arn:aws:iam::aws:policy/SecretsManagerReadWrite"]
  max_session_duration = "3600"
  name                 = "GitHubActionsCDKDeploy"
  path                 = "/"
}

resource "aws_iam_role" "tfer--agrovesto-infra-deploymen-CustomVpcRestrictDefaultS-Hzq7oZBnIJrR" {
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
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"ec2:AuthorizeSecurityGroupIngress\",\"ec2:AuthorizeSecurityGroupEgress\",\"ec2:RevokeSecurityGroupIngress\",\"ec2:RevokeSecurityGroupEgress\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:ec2:eu-west-1:221434544570:security-group/sg-05a2722a050c1109b\"]}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
  max_session_duration = "3600"
  name                 = "agrovesto-infra-deploymen-CustomVpcRestrictDefaultS-Hzq7oZBnIJrR"
  path                 = "/"
}

resource "aws_iam_role" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-UepjS11Nv8aU" {
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
    policy = "{\"Statement\":[{\"Action\":[\"secretsmanager:DescribeSecret\",\"secretsmanager:GetSecretValue\",\"secretsmanager:PutSecretValue\",\"secretsmanager:UpdateSecretVersionStage\"],\"Condition\":{\"StringEquals\":{\"secretsmanager:resource/AllowRotationLambdaArn\":\"arn:aws:lambda:eu-west-1:221434544570:function:agrovestoinfradeploymentnomaosdbRotationSingleUser77906076\"}},\"Effect\":\"Allow\",\"Resource\":\"arn:aws:secretsmanager:eu-west-1:221434544570:secret:*\"},{\"Action\":[\"secretsmanager:GetRandomPassword\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole", "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"]
  max_session_duration = "3600"
  name                 = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-UepjS11Nv8aU"
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

resource "aws_iam_role" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-yDIdim0P5oKG" {
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
    policy = "{\"Statement\":[{\"Action\":[\"secretsmanager:DescribeSecret\",\"secretsmanager:GetSecretValue\",\"secretsmanager:PutSecretValue\",\"secretsmanager:UpdateSecretVersionStage\"],\"Condition\":{\"StringEquals\":{\"secretsmanager:resource/AllowRotationLambdaArn\":\"arn:aws:lambda:eu-west-1:221434544570:function:agrovestoinfradeploymentagxdbRotationSingleUser096353C8\"}},\"Effect\":\"Allow\",\"Resource\":\"arn:aws:secretsmanager:eu-west-1:221434544570:secret:*\"},{\"Action\":[\"secretsmanager:GetRandomPassword\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole", "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"]
  max_session_duration = "3600"
  name                 = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-yDIdim0P5oKG"
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

resource "aws_iam_role" "tfer--agrovesto-infra-pipeline-CodePipelineRole-OF4B386rGJe4" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/PowerUserAccess"]
  max_session_duration = "3600"
  name                 = "agrovesto-infra-pipeline-CodePipelineRole-OF4B386rGJe4"
  path                 = "/"
}

resource "aws_iam_role" "tfer--agrovesto-prod-github-deploy" {
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
            "repo:Agrovesto@101108012/*:ref:refs/heads/arena/*",
            "repo:Agrovesto@101108012/*:pull_request"
          ]
        }
      },
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::221434544570:oidc-provider/token.actions.githubusercontent.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  description          = "Assumed by GitHub Actions (oidc/token.actions.githubusercontent.com) to terraform plan/apply the agrovesto-prod stack"
  managed_policy_arns  = ["arn:aws:iam::221434544570:policy/agrovesto-prod-github-deploy-policy"]
  max_session_duration = "3600"
  name                 = "agrovesto-prod-github-deploy"
  path                 = "/"

  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
    Project     = "agrovesto"
    Stack       = "bootstrap"
  }

  tags_all = {
    Environment = "prod"
    ManagedBy   = "terraform"
    Project     = "agrovesto"
    Stack       = "bootstrap"
  }
}

resource "aws_iam_role" "tfer--cdk-hnb659fds-cfn-exec-role-221434544570-eu-west-1" {
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
  name                 = "cdk-hnb659fds-cfn-exec-role-221434544570-eu-west-1"
  path                 = "/"
}

resource "aws_iam_role" "tfer--cdk-hnb659fds-deploy-role-221434544570-eu-west-1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:TagSession",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::221434544570:root"
      }
    },
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::221434544570:root"
      }
    }
  ],
  "Version": "2008-10-17"
}
POLICY

  inline_policy {
    name   = "default"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"cloudformation:CreateChangeSet\",\"cloudformation:DeleteChangeSet\",\"cloudformation:DescribeChangeSet\",\"cloudformation:DescribeStacks\",\"cloudformation:ExecuteChangeSet\",\"cloudformation:CreateStack\",\"cloudformation:UpdateStack\",\"cloudformation:RollbackStack\",\"cloudformation:ContinueUpdateRollback\"],\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"CloudFormationPermissions\"},{\"Action\":[\"s3:GetObject*\",\"s3:GetBucket*\",\"s3:List*\",\"s3:Abort*\",\"s3:DeleteObject*\",\"s3:PutObject*\"],\"Condition\":{\"StringNotEquals\":{\"s3:ResourceAccount\":\"221434544570\"}},\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"PipelineCrossAccountArtifactsBucket\"},{\"Action\":[\"kms:Decrypt\",\"kms:DescribeKey\",\"kms:Encrypt\",\"kms:ReEncrypt*\",\"kms:GenerateDataKey*\"],\"Condition\":{\"StringEquals\":{\"kms:ViaService\":\"s3.eu-west-1.amazonaws.com\"}},\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"PipelineCrossAccountArtifactsKey\"},{\"Action\":\"iam:PassRole\",\"Effect\":\"Allow\",\"Resource\":\"arn:aws:iam::221434544570:role/cdk-hnb659fds-cfn-exec-role-221434544570-eu-west-1\"},{\"Action\":[\"cloudformation:DescribeStackEvents\",\"cloudformation:GetTemplate\",\"cloudformation:DeleteStack\",\"cloudformation:UpdateTerminationProtection\",\"sts:GetCallerIdentity\",\"cloudformation:GetTemplateSummary\"],\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"CliPermissions\"},{\"Action\":[\"s3:GetObject*\",\"s3:GetBucket*\",\"s3:List*\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:s3:::cdk-hnb659fds-assets-221434544570-eu-west-1\",\"arn:aws:s3:::cdk-hnb659fds-assets-221434544570-eu-west-1/*\"],\"Sid\":\"CliStagingBucket\"},{\"Action\":[\"ssm:GetParameter\",\"ssm:GetParameters\"],\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:ssm:eu-west-1:221434544570:parameter/cdk-bootstrap/hnb659fds/version\"],\"Sid\":\"ReadVersion\"},{\"Action\":[\"cloudformation:CreateStackRefactor\",\"cloudformation:DescribeStackRefactor\",\"cloudformation:ExecuteStackRefactor\",\"cloudformation:ListStackRefactorActions\",\"cloudformation:ListStackRefactors\",\"cloudformation:ListStacks\"],\"Effect\":\"Allow\",\"Resource\":\"*\",\"Sid\":\"Refactor\"}]}"
  }

  max_session_duration = "3600"
  name                 = "cdk-hnb659fds-deploy-role-221434544570-eu-west-1"
  path                 = "/"

  tags = {
    "aws-cdk:bootstrap-role" = "deploy"
  }

  tags_all = {
    "aws-cdk:bootstrap-role" = "deploy"
  }
}

resource "aws_iam_role" "tfer--cdk-hnb659fds-file-publishing-role-221434544570-eu-west-1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:TagSession",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::221434544570:root"
      }
    },
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::221434544570:root"
      }
    }
  ],
  "Version": "2008-10-17"
}
POLICY

  inline_policy {
    name   = "cdk-hnb659fds-file-publishing-role-default-policy-221434544570-eu-west-1"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"s3:GetObject*\",\"s3:GetBucket*\",\"s3:GetEncryptionConfiguration\",\"s3:List*\",\"s3:DeleteObject*\",\"s3:PutObject*\",\"s3:Abort*\"],\"Condition\":{\"StringEquals\":{\"aws:ResourceAccount\":[\"221434544570\"]}},\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:s3:::cdk-hnb659fds-assets-221434544570-eu-west-1\",\"arn:aws:s3:::cdk-hnb659fds-assets-221434544570-eu-west-1/*\"]},{\"Action\":[\"kms:Decrypt\",\"kms:DescribeKey\",\"kms:Encrypt\",\"kms:ReEncrypt*\",\"kms:GenerateDataKey*\"],\"Effect\":\"Allow\",\"Resource\":\"arn:aws:kms:eu-west-1:221434544570:key/AWS_MANAGED_KEY\"}]}"
  }

  max_session_duration = "3600"
  name                 = "cdk-hnb659fds-file-publishing-role-221434544570-eu-west-1"
  path                 = "/"

  tags = {
    "aws-cdk:bootstrap-role" = "file-publishing"
  }

  tags_all = {
    "aws-cdk:bootstrap-role" = "file-publishing"
  }
}

resource "aws_iam_role" "tfer--cdk-hnb659fds-image-publishing-role-221434544570-eu-west-1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:TagSession",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::221434544570:root"
      }
    },
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::221434544570:root"
      }
    }
  ],
  "Version": "2008-10-17"
}
POLICY

  inline_policy {
    name   = "cdk-hnb659fds-image-publishing-role-default-policy-221434544570-eu-west-1"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"ecr:PutImage\",\"ecr:InitiateLayerUpload\",\"ecr:UploadLayerPart\",\"ecr:CompleteLayerUpload\",\"ecr:BatchCheckLayerAvailability\",\"ecr:DescribeRepositories\",\"ecr:DescribeImages\",\"ecr:BatchGetImage\",\"ecr:GetDownloadUrlForLayer\"],\"Effect\":\"Allow\",\"Resource\":\"arn:aws:ecr:eu-west-1:221434544570:repository/cdk-hnb659fds-container-assets-221434544570-eu-west-1\"},{\"Action\":[\"ecr:GetAuthorizationToken\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
  }

  max_session_duration = "3600"
  name                 = "cdk-hnb659fds-image-publishing-role-221434544570-eu-west-1"
  path                 = "/"

  tags = {
    "aws-cdk:bootstrap-role" = "image-publishing"
  }

  tags_all = {
    "aws-cdk:bootstrap-role" = "image-publishing"
  }
}

resource "aws_iam_role" "tfer--cdk-hnb659fds-lookup-role-221434544570-eu-west-1" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:TagSession",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::221434544570:root"
      }
    },
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::221434544570:root"
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
  name                 = "cdk-hnb659fds-lookup-role-221434544570-eu-west-1"
  path                 = "/"

  tags = {
    "aws-cdk:bootstrap-role" = "lookup"
  }

  tags_all = {
    "aws-cdk:bootstrap-role" = "lookup"
  }
}

resource "aws_iam_role" "tfer--dms-cloudwatch-logs-role" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "dms.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"]
  max_session_duration = "3600"
  name                 = "dms-cloudwatch-logs-role"
  path                 = "/"
}

resource "aws_iam_role" "tfer--dms-vpc-role" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "dms.amazonaws.com"
      },
      "Sid": ""
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"]
  max_session_duration = "3600"
  name                 = "dms-vpc-role"
  path                 = "/"
}

resource "aws_iam_role" "tfer--ec2_role-d0f2b8" {
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

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AmazonS3FullAccess", "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"]
  max_session_duration = "3600"
  name                 = "ec2_role-d0f2b8"
  path                 = "/"
}

resource "aws_iam_role" "tfer--instanceRole" {
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

  inline_policy {
    name   = "sts"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"iam:GetRole\",\"iam:GetInstanceProfile\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
  }

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AmazonSSMAutomationApproverAccess", "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess", "arn:aws:iam::aws:policy/AmazonSSMFullAccess", "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy", "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", "arn:aws:iam::aws:policy/AmazonSageMakerCanvasSMDataScienceAssistantAccess", "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy", "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM", "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole", "arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"]
  max_session_duration = "43200"
  name                 = "instanceRole"
  path                 = "/"
}

resource "aws_iam_role" "tfer--nomaos-prod-github-terraform" {
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
        "Federated": "arn:aws:iam::221434544570:oidc-provider/token.actions.githubusercontent.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  max_session_duration = "3600"
  name                 = "nomaos-prod-github-terraform"
  path                 = "/"

  tags = {
    Component  = "bootstrap"
    ManagedBy  = "terraform"
    Project    = "nomaos"
    Repository = "https://github.com/Agrovesto/ecs-prod-infra.git"
  }

  tags_all = {
    Component  = "bootstrap"
    ManagedBy  = "terraform"
    Project    = "nomaos"
    Repository = "https://github.com/Agrovesto/ecs-prod-infra.git"
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
