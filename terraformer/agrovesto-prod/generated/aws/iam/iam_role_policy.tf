resource "aws_iam_role_policy" "tfer--CodeBuildServiceRole_DevAssumeCodeBuildDeploymentRole" {
  name = "DevAssumeCodeBuildDeploymentRole"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Resource": "arn:aws:iam::*:role/CodeBuildDeploymentRole"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "CodeBuildServiceRole"
}

resource "aws_iam_role_policy" "tfer--CodeBuildServiceRole_DevCodeBuildLogsPolicy" {
  name = "DevCodeBuildLogsPolicy"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "logs:DescribeLogGroups",
        "logs:GetLogEvents",
        "logs:DeleteLogGroup",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DeleteLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:logs:*:*:log-group:/aws/codebuild/*",
        "arn:aws:logs:*:*:log-group:/aws/codebuild/*:log-stream:*",
        "arn:aws:s3:::*"
      ]
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "CodeBuildServiceRole"
}

resource "aws_iam_role_policy" "tfer--agrovesto-infra-deploymen-CustomVpcRestrictDefaultS-Hzq7oZBnIJrR_Inline" {
  name = "Inline"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:ec2:eu-west-1:221434544570:security-group/sg-05a2722a050c1109b"
      ]
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "agrovesto-infra-deploymen-CustomVpcRestrictDefaultS-Hzq7oZBnIJrR"
}

resource "aws_iam_role_policy" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-UepjS11Nv8aU_SecretsManagerRDSSQLServerRotationSingleUserRolePolicy0" {
  name = "SecretsManagerRDSSQLServerRotationSingleUserRolePolicy0"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DetachNetworkInterface"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
POLICY

  role = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-UepjS11Nv8aU"
}

resource "aws_iam_role_policy" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-UepjS11Nv8aU_SecretsManagerRDSSQLServerRotationSingleUserRolePolicy1" {
  name = "SecretsManagerRDSSQLServerRotationSingleUserRolePolicy1"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecretVersionStage"
      ],
      "Condition": {
        "StringEquals": {
          "secretsmanager:resource/AllowRotationLambdaArn": "arn:aws:lambda:eu-west-1:221434544570:function:agrovestoinfradeploymentnomaosdbRotationSingleUser77906076"
        }
      },
      "Effect": "Allow",
      "Resource": "arn:aws:secretsmanager:eu-west-1:221434544570:secret:*"
    },
    {
      "Action": [
        "secretsmanager:GetRandomPassword"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
POLICY

  role = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-UepjS11Nv8aU"
}

resource "aws_iam_role_policy" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-yDIdim0P5oKG_SecretsManagerRDSSQLServerRotationSingleUserRolePolicy0" {
  name = "SecretsManagerRDSSQLServerRotationSingleUserRolePolicy0"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DetachNetworkInterface"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
POLICY

  role = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-yDIdim0P5oKG"
}

resource "aws_iam_role_policy" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-yDIdim0P5oKG_SecretsManagerRDSSQLServerRotationSingleUserRolePolicy1" {
  name = "SecretsManagerRDSSQLServerRotationSingleUserRolePolicy1"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecretVersionStage"
      ],
      "Condition": {
        "StringEquals": {
          "secretsmanager:resource/AllowRotationLambdaArn": "arn:aws:lambda:eu-west-1:221434544570:function:agrovestoinfradeploymentagxdbRotationSingleUser096353C8"
        }
      },
      "Effect": "Allow",
      "Resource": "arn:aws:secretsmanager:eu-west-1:221434544570:secret:*"
    },
    {
      "Action": [
        "secretsmanager:GetRandomPassword"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
POLICY

  role = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-yDIdim0P5oKG"
}

resource "aws_iam_role_policy" "tfer--cdk-hnb659fds-deploy-role-221434544570-eu-west-1_default" {
  name = "default"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "cloudformation:CreateChangeSet",
        "cloudformation:DeleteChangeSet",
        "cloudformation:DescribeChangeSet",
        "cloudformation:DescribeStacks",
        "cloudformation:ExecuteChangeSet",
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:RollbackStack",
        "cloudformation:ContinueUpdateRollback"
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "CloudFormationPermissions"
    },
    {
      "Action": [
        "s3:GetObject*",
        "s3:GetBucket*",
        "s3:List*",
        "s3:Abort*",
        "s3:DeleteObject*",
        "s3:PutObject*"
      ],
      "Condition": {
        "StringNotEquals": {
          "s3:ResourceAccount": "221434544570"
        }
      },
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "PipelineCrossAccountArtifactsBucket"
    },
    {
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*"
      ],
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "s3.eu-west-1.amazonaws.com"
        }
      },
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "PipelineCrossAccountArtifactsKey"
    },
    {
      "Action": "iam:PassRole",
      "Effect": "Allow",
      "Resource": "arn:aws:iam::221434544570:role/cdk-hnb659fds-cfn-exec-role-221434544570-eu-west-1"
    },
    {
      "Action": [
        "cloudformation:DescribeStackEvents",
        "cloudformation:GetTemplate",
        "cloudformation:DeleteStack",
        "cloudformation:UpdateTerminationProtection",
        "sts:GetCallerIdentity",
        "cloudformation:GetTemplateSummary"
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "CliPermissions"
    },
    {
      "Action": [
        "s3:GetObject*",
        "s3:GetBucket*",
        "s3:List*"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::cdk-hnb659fds-assets-221434544570-eu-west-1",
        "arn:aws:s3:::cdk-hnb659fds-assets-221434544570-eu-west-1/*"
      ],
      "Sid": "CliStagingBucket"
    },
    {
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:ssm:eu-west-1:221434544570:parameter/cdk-bootstrap/hnb659fds/version"
      ],
      "Sid": "ReadVersion"
    },
    {
      "Action": [
        "cloudformation:CreateStackRefactor",
        "cloudformation:DescribeStackRefactor",
        "cloudformation:ExecuteStackRefactor",
        "cloudformation:ListStackRefactorActions",
        "cloudformation:ListStackRefactors",
        "cloudformation:ListStacks"
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "Refactor"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "cdk-hnb659fds-deploy-role-221434544570-eu-west-1"
}

resource "aws_iam_role_policy" "tfer--cdk-hnb659fds-file-publishing-role-221434544570-eu-west-1_cdk-hnb659fds-file-publishing-role-default-policy-221434544570-eu-west-1" {
  name = "cdk-hnb659fds-file-publishing-role-default-policy-221434544570-eu-west-1"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "s3:GetObject*",
        "s3:GetBucket*",
        "s3:GetEncryptionConfiguration",
        "s3:List*",
        "s3:DeleteObject*",
        "s3:PutObject*",
        "s3:Abort*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:ResourceAccount": [
            "221434544570"
          ]
        }
      },
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::cdk-hnb659fds-assets-221434544570-eu-west-1",
        "arn:aws:s3:::cdk-hnb659fds-assets-221434544570-eu-west-1/*"
      ]
    },
    {
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:kms:eu-west-1:221434544570:key/AWS_MANAGED_KEY"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "cdk-hnb659fds-file-publishing-role-221434544570-eu-west-1"
}

resource "aws_iam_role_policy" "tfer--cdk-hnb659fds-image-publishing-role-221434544570-eu-west-1_cdk-hnb659fds-image-publishing-role-default-policy-221434544570-eu-west-1" {
  name = "cdk-hnb659fds-image-publishing-role-default-policy-221434544570-eu-west-1"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:BatchCheckLayerAvailability",
        "ecr:DescribeRepositories",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:ecr:eu-west-1:221434544570:repository/cdk-hnb659fds-container-assets-221434544570-eu-west-1"
    },
    {
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "cdk-hnb659fds-image-publishing-role-221434544570-eu-west-1"
}

resource "aws_iam_role_policy" "tfer--cdk-hnb659fds-lookup-role-221434544570-eu-west-1_LookupRolePolicy" {
  name = "LookupRolePolicy"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "kms:Decrypt"
      ],
      "Effect": "Deny",
      "Resource": "*",
      "Sid": "DontReadSecrets"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "cdk-hnb659fds-lookup-role-221434544570-eu-west-1"
}

resource "aws_iam_role_policy" "tfer--instanceRole_sts" {
  name = "sts"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "iam:GetRole",
        "iam:GetInstanceProfile"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "instanceRole"
}
