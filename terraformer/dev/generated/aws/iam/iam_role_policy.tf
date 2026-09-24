resource "aws_iam_role_policy" "tfer--AWSCodePipelineServiceRole-eu-west-1-nomaos_AmplifyCdkAssetPublishing" {
  name = "AmplifyCdkAssetPublishing"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1",
        "arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1/*"
      ],
      "Sid": "AllowAmplifyToPublishCDKAssets"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "AWSCodePipelineServiceRole-eu-west-1-nomaos"
}

resource "aws_iam_role_policy" "tfer--AWSCodePipelineServiceRole-eu-west-1-nomaos_AmplifyCdkBootstrapAccess" {
  name = "AmplifyCdkBootstrapAccess"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": "ssm:GetParameter",
      "Effect": "Allow",
      "Resource": "arn:aws:ssm:eu-central-1:353833416626:parameter/cdk-bootstrap/hnb659fds/version",
      "Sid": "AllowAmplifyToReadCDKBootstrap"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "AWSCodePipelineServiceRole-eu-west-1-nomaos"
}

resource "aws_iam_role_policy" "tfer--AWSCodePipelineServiceRole-eu-west-1-nomaos_codepipeline" {
  name = "codepipeline"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:logs:eu-west-1:353833416626:log-group:/aws/codepipeline/*"
      ],
      "Sid": "AllowCloudWatchLogs"
    },
    {
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeTags",
        "ec2:DescribeInstanceStatus"
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "AllowEC2Describe"
    },
    {
      "Action": [
        "ssm:SendCommand",
        "ssm:ListCommands",
        "ssm:ListCommandInvocations"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:ec2:eu-west-1:353833416626:instance/*",
        "arn:aws:ssm:eu-west-1:353833416626:document/*"
      ],
      "Sid": "AllowSSMSendCommand"
    },
    {
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::codepipeline-eu-west-1-3bf3ec101df5-4d09-9689-376482a069ed/*",
      "Sid": "AllowCodePipelineS3Access"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "AWSCodePipelineServiceRole-eu-west-1-nomaos"
}

resource "aws_iam_role_policy" "tfer--GuestEntryIAMRoleffc357-beg42uuyereqjerfalxrk72nmq-NONE_DynamoDBAccess" {
  name = "DynamoDBAccess"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:GetItem",
        "dynamodb:Scan",
        "dynamodb:Query",
        "dynamodb:UpdateItem",
        "dynamodb:ConditionCheckItem",
        "dynamodb:DescribeTable",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:dynamodb:eu-central-1:353833416626:table/GuestEntry-beg42uuyereqjerfalxrk72nmq-NONE",
        "arn:aws:dynamodb:eu-central-1:353833416626:table/GuestEntry-beg42uuyereqjerfalxrk72nmq-NONE/*"
      ]
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "GuestEntryIAMRoleffc357-beg42uuyereqjerfalxrk72nmq-NONE"
}

resource "aws_iam_role_policy" "tfer--MediaItemIAMRole3fae1c-beg42uuyereqjerfalxrk72nmq-NONE_DynamoDBAccess" {
  name = "DynamoDBAccess"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:GetItem",
        "dynamodb:Scan",
        "dynamodb:Query",
        "dynamodb:UpdateItem",
        "dynamodb:ConditionCheckItem",
        "dynamodb:DescribeTable",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:dynamodb:eu-central-1:353833416626:table/MediaItem-beg42uuyereqjerfalxrk72nmq-NONE",
        "arn:aws:dynamodb:eu-central-1:353833416626:table/MediaItem-beg42uuyereqjerfalxrk72nmq-NONE/*"
      ]
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "MediaItemIAMRole3fae1c-beg42uuyereqjerfalxrk72nmq-NONE"
}

resource "aws_iam_role_policy" "tfer--agrovesto-infra-deploymen-CustomVpcRestrictDefaultS-wHppFzTSRAd1_Inline" {
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
        "arn:aws:ec2:eu-west-1:353833416626:security-group/sg-032197de8d143373f"
      ]
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "agrovesto-infra-deploymen-CustomVpcRestrictDefaultS-wHppFzTSRAd1"
}

resource "aws_iam_role_policy" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-DTg5g94z5aY6_SecretsManagerRDSSQLServerRotationSingleUserRolePolicy0" {
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

  role = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-DTg5g94z5aY6"
}

resource "aws_iam_role_policy" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-DTg5g94z5aY6_SecretsManagerRDSSQLServerRotationSingleUserRolePolicy1" {
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
          "secretsmanager:resource/AllowRotationLambdaArn": "arn:aws:lambda:eu-west-1:353833416626:function:agrovestoinfradeploymentagxdbRotationSingleUser096353C8"
        }
      },
      "Effect": "Allow",
      "Resource": "arn:aws:secretsmanager:eu-west-1:353833416626:secret:*"
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

  role = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-DTg5g94z5aY6"
}

resource "aws_iam_role_policy" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-EXyHA0Ipenan_SecretsManagerRDSSQLServerRotationSingleUserRolePolicy0" {
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

  role = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-EXyHA0Ipenan"
}

resource "aws_iam_role_policy" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-EXyHA0Ipenan_SecretsManagerRDSSQLServerRotationSingleUserRolePolicy1" {
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
          "secretsmanager:resource/AllowRotationLambdaArn": "arn:aws:lambda:eu-west-1:353833416626:function:agrovestoinfradeploymentnomaosdbRotationSingleUser77906076"
        }
      },
      "Effect": "Allow",
      "Resource": "arn:aws:secretsmanager:eu-west-1:353833416626:secret:*"
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

  role = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-EXyHA0Ipenan"
}

resource "aws_iam_role_policy" "tfer--amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCustom-ejNMfppltfPg_AmplifyBranchLinkerCustomResourceProviderframeworkonEventServiceRoleDefaultPolicy38AAE412" {
  name = "AmplifyBranchLinkerCustomResourceProviderframeworkonEventServiceRoleDefaultPolicy38AAE412"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": "lambda:InvokeFunction",
      "Effect": "Allow",
      "Resource": [
        "arn:aws:lambda:eu-central-1:353833416626:function:amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCusto-TIbEIMcYF5NU",
        "arn:aws:lambda:eu-central-1:353833416626:function:amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCusto-TIbEIMcYF5NU:*"
      ]
    },
    {
      "Action": "lambda:GetFunction",
      "Effect": "Allow",
      "Resource": "arn:aws:lambda:eu-central-1:353833416626:function:amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCusto-TIbEIMcYF5NU"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCustom-ejNMfppltfPg"
}

resource "aws_iam_role_policy" "tfer--amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCustom-fzp661Q35Odb_AmplifyBranchLinkerCustomResourceLambdaServiceRoleDefaultPolicy86099CA1" {
  name = "AmplifyBranchLinkerCustomResourceLambdaServiceRoleDefaultPolicy86099CA1"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "amplify:GetBranch",
        "amplify:UpdateBranch"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:amplify:*:*:apps/d3setdk1gwy695/branches/main"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCustom-fzp661Q35Odb"
}

resource "aws_iam_role_policy" "tfer--amplify-d3setdk1gwy695-ma-AmplifyManagedTableIsComp-rcS8Djx2OFrP_CreateUpdateDeleteTablesPolicy" {
  name = "CreateUpdateDeleteTablesPolicy"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:UpdateTable",
        "dynamodb:DeleteTable",
        "dynamodb:DescribeTable",
        "dynamodb:DescribeContinuousBackups",
        "dynamodb:DescribeTimeToLive",
        "dynamodb:UpdateContinuousBackups",
        "dynamodb:UpdateTimeToLive",
        "dynamodb:TagResource",
        "dynamodb:UntagResource",
        "dynamodb:ListTagsOfResource"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:dynamodb:eu-central-1:353833416626:table/*-beg42uuyereqjerfalxrk72nmq-NONE"
    },
    {
      "Action": "lambda:ListTags",
      "Effect": "Allow",
      "Resource": "arn:aws:lambda:eu-central-1:353833416626:function:*TableManager*"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "amplify-d3setdk1gwy695-ma-AmplifyManagedTableIsComp-rcS8Djx2OFrP"
}

resource "aws_iam_role_policy" "tfer--amplify-d3setdk1gwy695-ma-AmplifyManagedTableOnEven-SnL0p2y5qusS_AmplifyManagedTableOnEventRoleDefaultPolicyF6DABCB6" {
  name = "AmplifyManagedTableOnEventRoleDefaultPolicyF6DABCB6"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": "states:StartExecution",
      "Effect": "Allow",
      "Resource": "arn:aws:states:eu-central-1:353833416626:stateMachine:AmplifyTableWaiterStateMachine060600BC-QZV6ZLw5IuQN"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "amplify-d3setdk1gwy695-ma-AmplifyManagedTableOnEven-SnL0p2y5qusS"
}

resource "aws_iam_role_policy" "tfer--amplify-d3setdk1gwy695-ma-AmplifyManagedTableOnEven-SnL0p2y5qusS_CreateUpdateDeleteTablesPolicy" {
  name = "CreateUpdateDeleteTablesPolicy"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:UpdateTable",
        "dynamodb:DeleteTable",
        "dynamodb:DescribeTable",
        "dynamodb:DescribeContinuousBackups",
        "dynamodb:DescribeTimeToLive",
        "dynamodb:UpdateContinuousBackups",
        "dynamodb:UpdateTimeToLive",
        "dynamodb:TagResource",
        "dynamodb:UntagResource",
        "dynamodb:ListTagsOfResource"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:dynamodb:eu-central-1:353833416626:table/*-beg42uuyereqjerfalxrk72nmq-NONE"
    },
    {
      "Action": "lambda:ListTags",
      "Effect": "Allow",
      "Resource": "arn:aws:lambda:eu-central-1:353833416626:function:*TableManager*"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "amplify-d3setdk1gwy695-ma-AmplifyManagedTableOnEven-SnL0p2y5qusS"
}

resource "aws_iam_role_policy" "tfer--amplify-d3setdk1gwy695-ma-AmplifyTableWaiterStateMa-I3G2jMlyNE9g_AmplifyTableWaiterStateMachineRoleDefaultPolicy89F3836A" {
  name = "AmplifyTableWaiterStateMachineRoleDefaultPolicy89F3836A"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": "lambda:InvokeFunction",
      "Effect": "Allow",
      "Resource": [
        "arn:aws:lambda:eu-central-1:353833416626:function:amplify-d3setdk1gwy695-ma-TableManagerCustomProvid-uhpMyup4WP7D",
        "arn:aws:lambda:eu-central-1:353833416626:function:amplify-d3setdk1gwy695-ma-TableManagerCustomProvid-uhpMyup4WP7D:*"
      ]
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "amplify-d3setdk1gwy695-ma-AmplifyTableWaiterStateMa-I3G2jMlyNE9g"
}

resource "aws_iam_role_policy" "tfer--amplify-d3setdk1gwy695-ma-CustomCDKBucketDeployment-pZMgmQWVhiQn_CustomCDKBucketDeployment8693BB64968944B69AAFB0CC9EB8756C1536MiBServiceRoleDefaultPolicyFF1C635B" {
  name = "CustomCDKBucketDeployment8693BB64968944B69AAFB0CC9EB8756C1536MiBServiceRoleDefaultPolicyFF1C635B"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "s3:GetObject*",
        "s3:GetBucket*",
        "s3:List*"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1",
        "arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1/*"
      ]
    },
    {
      "Action": [
        "s3:GetObject*",
        "s3:GetBucket*",
        "s3:List*",
        "s3:DeleteObject*",
        "s3:PutObject",
        "s3:PutObjectLegalHold",
        "s3:PutObjectRetention",
        "s3:PutObjectTagging",
        "s3:PutObjectVersionTagging",
        "s3:Abort*"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::amplify-d3setdk1gwy695-ma-amplifydataamplifycodege-mubkzp2mfehx",
        "arn:aws:s3:::amplify-d3setdk1gwy695-ma-amplifydataamplifycodege-mubkzp2mfehx/*"
      ]
    },
    {
      "Action": [
        "s3:GetObject*",
        "s3:GetBucket*",
        "s3:List*",
        "s3:DeleteObject*",
        "s3:PutObject",
        "s3:PutObjectLegalHold",
        "s3:PutObjectRetention",
        "s3:PutObjectTagging",
        "s3:PutObjectVersionTagging",
        "s3:Abort*"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::amplify-d3setdk1gwy695-ma-modelintrospectionschema-xv7wrateaqhd",
        "arn:aws:s3:::amplify-d3setdk1gwy695-ma-modelintrospectionschema-xv7wrateaqhd/*"
      ]
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "amplify-d3setdk1gwy695-ma-CustomCDKBucketDeployment-pZMgmQWVhiQn"
}

resource "aws_iam_role_policy" "tfer--amplify-d3setdk1gwy695-ma-amplifyAuthauthenticatedU-9bTF5ojNgNm7_amplifyd3setdk1gwy695mainbranch467367b8b9storageAccess4BE0C7C0F" {
  name = "amplifyd3setdk1gwy695mainbranch467367b8b9storageAccess4BE0C7C0F"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": "s3:GetObject",
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/media/*",
        "arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/admin/*"
      ]
    },
    {
      "Action": "s3:ListBucket",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "media/*",
            "media/",
            "admin/*",
            "admin/"
          ]
        }
      },
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5"
    },
    {
      "Action": "s3:PutObject",
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/media/*",
        "arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/admin/*"
      ]
    },
    {
      "Action": "s3:DeleteObject",
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/media/*",
        "arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/admin/*"
      ]
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "amplify-d3setdk1gwy695-ma-amplifyAuthauthenticatedU-9bTF5ojNgNm7"
}

resource "aws_iam_role_policy" "tfer--amplify-d3setdk1gwy695-ma-amplifyAuthunauthenticate-PeKmwwLSiQEo_amplifyd3setdk1gwy695mainbranch467367b8b9storageAccess395743666" {
  name = "amplifyd3setdk1gwy695mainbranch467367b8b9storageAccess395743666"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": "s3:GetObject",
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/media/*"
    },
    {
      "Action": "s3:ListBucket",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "media/*",
            "media/"
          ]
        }
      },
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5"
    },
    {
      "Action": "s3:PutObject",
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/media/*"
    },
    {
      "Action": "s3:PutObject",
      "Effect": "Deny",
      "Resource": [
        "arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/media/processed/*",
        "arn:aws:s3:::amplify-d3setdk1gwy695-ma-weddingmediabucket73c660-pnf0xlnhrkj5/media/thumbnails/*"
      ]
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "amplify-d3setdk1gwy695-ma-amplifyAuthunauthenticate-PeKmwwLSiQEo"
}

resource "aws_iam_role_policy" "tfer--cdk-hnb659fds-deploy-role-353833416626-eu-central-1_default" {
  name = "default"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "cloudformation:CreateChangeSet",
        "cloudformation:DeleteChangeSet",
        "cloudformation:ExecuteChangeSet",
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:RollbackStack",
        "cloudformation:ContinueUpdateRollback"
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "DeployPermissions"
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
          "s3:ResourceAccount": "353833416626"
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
          "kms:ViaService": "s3.eu-central-1.amazonaws.com"
        }
      },
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "PipelineCrossAccountArtifactsKey"
    },
    {
      "Action": "iam:PassRole",
      "Effect": "Allow",
      "Resource": "arn:aws:iam::353833416626:role/cdk-hnb659fds-cfn-exec-role-353833416626-eu-central-1"
    },
    {
      "Action": [
        "cloudformation:DeleteStack",
        "cloudformation:UpdateTerminationProtection",
        "sts:GetCallerIdentity"
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
        "arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1",
        "arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1/*"
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
        "arn:aws:ssm:eu-central-1:353833416626:parameter/cdk-bootstrap/hnb659fds/version"
      ],
      "Sid": "ReadVersion"
    },
    {
      "Action": [
        "cloudformation:CreateStackRefactor",
        "cloudformation:ExecuteStackRefactor"
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "Refactor"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "cdk-hnb659fds-deploy-role-353833416626-eu-central-1"
}

resource "aws_iam_role_policy" "tfer--cdk-hnb659fds-deploy-role-353833416626-eu-west-1_default" {
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
          "s3:ResourceAccount": "353833416626"
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
      "Resource": "arn:aws:iam::353833416626:role/cdk-hnb659fds-cfn-exec-role-353833416626-eu-west-1"
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
        "arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-west-1",
        "arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-west-1/*"
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
        "arn:aws:ssm:eu-west-1:353833416626:parameter/cdk-bootstrap/hnb659fds/version"
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

  role = "cdk-hnb659fds-deploy-role-353833416626-eu-west-1"
}

resource "aws_iam_role_policy" "tfer--cdk-hnb659fds-file-publishing-role-353833416626-eu-central-1_cdk-hnb659fds-file-publishing-role-default-policy-353833416626-eu-central-1" {
  name = "cdk-hnb659fds-file-publishing-role-default-policy-353833416626-eu-central-1"

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
            "353833416626"
          ]
        }
      },
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1",
        "arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-central-1/*"
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
      "Resource": "arn:aws:kms:eu-central-1:353833416626:key/AWS_MANAGED_KEY"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "cdk-hnb659fds-file-publishing-role-353833416626-eu-central-1"
}

resource "aws_iam_role_policy" "tfer--cdk-hnb659fds-file-publishing-role-353833416626-eu-west-1_cdk-hnb659fds-file-publishing-role-default-policy-353833416626-eu-west-1" {
  name = "cdk-hnb659fds-file-publishing-role-default-policy-353833416626-eu-west-1"

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
            "353833416626"
          ]
        }
      },
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-west-1",
        "arn:aws:s3:::cdk-hnb659fds-assets-353833416626-eu-west-1/*"
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
      "Resource": "arn:aws:kms:eu-west-1:353833416626:key/AWS_MANAGED_KEY"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "cdk-hnb659fds-file-publishing-role-353833416626-eu-west-1"
}

resource "aws_iam_role_policy" "tfer--cdk-hnb659fds-image-publishing-role-353833416626-eu-central-1_cdk-hnb659fds-image-publishing-role-default-policy-353833416626-eu-central-1" {
  name = "cdk-hnb659fds-image-publishing-role-default-policy-353833416626-eu-central-1"

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
      "Resource": "arn:aws:ecr:eu-central-1:353833416626:repository/cdk-hnb659fds-container-assets-353833416626-eu-central-1"
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

  role = "cdk-hnb659fds-image-publishing-role-353833416626-eu-central-1"
}

resource "aws_iam_role_policy" "tfer--cdk-hnb659fds-image-publishing-role-353833416626-eu-west-1_cdk-hnb659fds-image-publishing-role-default-policy-353833416626-eu-west-1" {
  name = "cdk-hnb659fds-image-publishing-role-default-policy-353833416626-eu-west-1"

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
      "Resource": "arn:aws:ecr:eu-west-1:353833416626:repository/cdk-hnb659fds-container-assets-353833416626-eu-west-1"
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

  role = "cdk-hnb659fds-image-publishing-role-353833416626-eu-west-1"
}

resource "aws_iam_role_policy" "tfer--cdk-hnb659fds-lookup-role-353833416626-eu-central-1_LookupRolePolicy" {
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

  role = "cdk-hnb659fds-lookup-role-353833416626-eu-central-1"
}

resource "aws_iam_role_policy" "tfer--cdk-hnb659fds-lookup-role-353833416626-eu-west-1_LookupRolePolicy" {
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

  role = "cdk-hnb659fds-lookup-role-353833416626-eu-west-1"
}

resource "aws_iam_role_policy" "tfer--nomaos-amplify_amplifyaccess" {
  name = "amplifyaccess"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Resource": "arn:aws:iam::*:role/cdk-hnb659fds-*"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "nomaos-amplify"
}

resource "aws_iam_role_policy" "tfer--nomaos-bootstrap-dev-deploy_BoundedWorkloadIAM" {
  name = "BoundedWorkloadIAM"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:GetInstanceProfile",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListInstanceProfilesForRole",
        "iam:ListRoleTags",
        "iam:ListInstanceProfileTags"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:iam::353833416626:role/nomaos-dev-*",
        "arn:aws:iam::353833416626:role/aws-service-role/*",
        "arn:aws:iam::353833416626:instance-profile/nomaos-dev-*",
        "arn:aws:iam::353833416626:policy/nomaos-bootstrap-dev-workload-boundary",
        "arn:aws:iam::aws:policy/*"
      ],
      "Sid": "IAMReadOnly"
    },
    {
      "Action": "iam:CreateRole",
      "Condition": {
        "StringEquals": {
          "iam:PermissionsBoundary": "arn:aws:iam::353833416626:policy/nomaos-bootstrap-dev-workload-boundary"
        }
      },
      "Effect": "Allow",
      "Resource": "arn:aws:iam::353833416626:role/nomaos-dev-*",
      "Sid": "CreateOnlyBoundedRoles"
    },
    {
      "Action": [
        "iam:DeleteRole",
        "iam:UpdateRole",
        "iam:UpdateRoleDescription",
        "iam:UpdateAssumeRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:DetachRolePolicy"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:iam::353833416626:role/nomaos-dev-*",
      "Sid": "ManageOnlyWorkloadRoles"
    },
    {
      "Action": "iam:AttachRolePolicy",
      "Condition": {
        "ArnEquals": {
          "iam:PolicyARN": [
            "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
            "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup",
            "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
          ]
        }
      },
      "Effect": "Allow",
      "Resource": "arn:aws:iam::353833416626:role/nomaos-dev-*",
      "Sid": "ApprovedAWSRuntimePoliciesOnly"
    },
    {
      "Action": [
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:TagInstanceProfile",
        "iam:UntagInstanceProfile"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:iam::353833416626:instance-profile/nomaos-dev-*",
      "Sid": "ManageWorkloadInstanceProfiles"
    },
    {
      "Action": "iam:PassRole",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": [
            "ec2.amazonaws.com",
            "ecs-tasks.amazonaws.com",
            "rds.amazonaws.com",
            "monitoring.rds.amazonaws.com",
            "backup.amazonaws.com",
            "vpc-flow-logs.amazonaws.com",
            "cloudtrail.amazonaws.com",
            "events.amazonaws.com"
          ]
        }
      },
      "Effect": "Allow",
      "Resource": "arn:aws:iam::353833416626:role/nomaos-dev-*",
      "Sid": "PassOnlyWorkloadRolesToServices"
    },
    {
      "Action": "iam:CreateServiceLinkedRole",
      "Condition": {
        "StringEquals": {
          "iam:AWSServiceName": [
            "ecs.amazonaws.com",
            "ecs.application-autoscaling.amazonaws.com",
            "elasticloadbalancing.amazonaws.com",
            "rds.amazonaws.com",
            "backup.amazonaws.com",
            "guardduty.amazonaws.com"
          ]
        }
      },
      "Effect": "Allow",
      "Resource": "arn:aws:iam::353833416626:role/aws-service-role/*",
      "Sid": "RequiredServiceLinkedRoles"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "nomaos-bootstrap-dev-deploy"
}

resource "aws_iam_role_policy" "tfer--nomaos-bootstrap-dev-deploy_ProvisionInfrastructureServices" {
  name = "ProvisionInfrastructureServices"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "ec2:*",
        "elasticloadbalancing:*",
        "ecs:*",
        "ecr:*",
        "rds:*",
        "application-autoscaling:*",
        "autoscaling:Describe*",
        "s3:*",
        "kms:*",
        "logs:*",
        "cloudwatch:*",
        "sns:*",
        "budgets:*",
        "backup:*",
        "events:*",
        "ssm:*",
        "secretsmanager:*",
        "acm:*",
        "route53:*",
        "amplify:*",
        "cloudtrail:*",
        "guardduty:*"
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "InfrastructureServices"
    },
    {
      "Action": [
        "s3:DeleteBucket",
        "s3:DeleteBucketPolicy",
        "s3:PutBucket*",
        "s3:PutEncryptionConfiguration",
        "s3:PutLifecycleConfiguration",
        "s3:PutReplicationConfiguration",
        "s3:PutAccelerateConfiguration",
        "s3:DeleteObjectVersion"
      ],
      "Effect": "Deny",
      "Resource": [
        "arn:aws:s3:::nomaos-tfstate-353833416626-eu-west-1",
        "arn:aws:s3:::nomaos-tfstate-353833416626-eu-west-1/*",
        "arn:aws:s3:::nomaos-tfstate-logs-353833416626-eu-west-1",
        "arn:aws:s3:::nomaos-tfstate-logs-353833416626-eu-west-1/*"
      ],
      "Sid": "ProtectBackendConfiguration"
    },
    {
      "Action": "s3:*",
      "Effect": "Deny",
      "Resource": "arn:aws:s3:::nomaos-tfstate-353833416626-eu-west-1/dev/bootstrap.tfstate*",
      "Sid": "ProtectBootstrapState"
    },
    {
      "Action": "s3:DeleteObject",
      "Effect": "Deny",
      "Resource": "arn:aws:s3:::nomaos-tfstate-353833416626-eu-west-1/dev/terraform.tfstate",
      "Sid": "DoNotDeleteEnvironmentState"
    },
    {
      "Effect": "Deny",
      "NotAction": [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": [
        "arn:aws:kms:eu-west-1:353833416626:key/31f57b1f-cbde-4aa6-8c6e-18e129c80fb6",
        "arn:aws:kms:eu-west-1:353833416626:alias/nomaos-bootstrap-dev"
      ],
      "Sid": "ProtectBackendKey"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "nomaos-bootstrap-dev-deploy"
}

resource "aws_iam_role_policy" "tfer--ssmrole_iam" {
  name = "iam"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "iam:GetRole",
        "iam:GetRolePolicy"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  role = "ssmrole"
}
