resource "aws_iam_policy" "tfer--AWSCodePipelineServiceRole-eu-west-1-nomaos" {
  description = "Policy used in trust relationship with CodePipeline for service role"
  name        = "AWSCodePipelineServiceRole-eu-west-1-nomaos"
  path        = "/service-role/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "s3:GetBucketVersioning",
        "s3:GetBucketAcl",
        "s3:GetBucketLocation"
      ],
      "Condition": {
        "StringEquals": {
          "aws:ResourceAccount": "353833416626"
        }
      },
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::codepipeline-eu-west-1-3bf3ec101df5-4d09-9689-376482a069ed"
      ],
      "Sid": "AllowS3BucketAccess"
    },
    {
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:GetObjectVersion"
      ],
      "Condition": {
        "StringEquals": {
          "aws:ResourceAccount": "353833416626"
        }
      },
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::codepipeline-eu-west-1-3bf3ec101df5-4d09-9689-376482a069ed/*"
      ],
      "Sid": "AllowS3ObjectAccess"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--AWSLambdaBasicExecutionRole-11c81ffa-eaed-45b5-b356-bf24894d1193" {
  name = "AWSLambdaBasicExecutionRole-11c81ffa-eaed-45b5-b356-bf24894d1193"
  path = "/service-role/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": "logs:CreateLogGroup",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:*"
    },
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:logs:eu-west-1:353833416626:log-group:/aws/lambda/test:*"
      ]
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--AWSLambdaVPCAccessExecutionRole-6aa51a87-0e83-4869-be44-e074cad3bc76" {
  name = "AWSLambdaVPCAccessExecutionRole-6aa51a87-0e83-4869-be44-e074cad3bc76"
  path = "/service-role/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeNetworkInterfaces"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--AmplifySSRLoggingPolicy-4fb94426-a00e-4cd2-9ea2-2d0bd82fd3e1" {
  name = "AmplifySSRLoggingPolicy-4fb94426-a00e-4cd2-9ea2-2d0bd82fd3e1"
  path = "/service-role/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:/aws/amplify/*:log-stream:*",
      "Sid": "PushLogs"
    },
    {
      "Action": "logs:CreateLogGroup",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:/aws/amplify/*",
      "Sid": "CreateLogGroup"
    },
    {
      "Action": "logs:DescribeLogGroups",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:*",
      "Sid": "DescribeLogGroups"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--AmplifySSRLoggingPolicy-640973d5-6399-421a-ac2a-ba65df815c56" {
  name = "AmplifySSRLoggingPolicy-640973d5-6399-421a-ac2a-ba65df815c56"
  path = "/service-role/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:/aws/amplify/*:log-stream:*",
      "Sid": "PushLogs"
    },
    {
      "Action": "logs:CreateLogGroup",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:/aws/amplify/*",
      "Sid": "CreateLogGroup"
    },
    {
      "Action": "logs:DescribeLogGroups",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:*",
      "Sid": "DescribeLogGroups"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--AmplifySSRLoggingPolicy-702a70a4-375c-468f-97d4-4641dd448284" {
  name = "AmplifySSRLoggingPolicy-702a70a4-375c-468f-97d4-4641dd448284"
  path = "/service-role/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:/aws/amplify/*:log-stream:*",
      "Sid": "PushLogs"
    },
    {
      "Action": "logs:CreateLogGroup",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:/aws/amplify/*",
      "Sid": "CreateLogGroup"
    },
    {
      "Action": "logs:DescribeLogGroups",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:*",
      "Sid": "DescribeLogGroups"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--AmplifySSRLoggingPolicy-739d4bc2-0a8d-4a1b-9796-ea41cf9cfc87" {
  name = "AmplifySSRLoggingPolicy-739d4bc2-0a8d-4a1b-9796-ea41cf9cfc87"
  path = "/service-role/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-central-1:353833416626:log-group:/aws/amplify/*:log-stream:*",
      "Sid": "PushLogs"
    },
    {
      "Action": "logs:CreateLogGroup",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-central-1:353833416626:log-group:/aws/amplify/*",
      "Sid": "CreateLogGroup"
    },
    {
      "Action": "logs:DescribeLogGroups",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-central-1:353833416626:log-group:*",
      "Sid": "DescribeLogGroups"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--AmplifySSRLoggingPolicy-77230cc0-0b08-4dc4-be4b-98f0a92c9b9b" {
  name = "AmplifySSRLoggingPolicy-77230cc0-0b08-4dc4-be4b-98f0a92c9b9b"
  path = "/service-role/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:/aws/amplify/*:log-stream:*",
      "Sid": "PushLogs"
    },
    {
      "Action": "logs:CreateLogGroup",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:/aws/amplify/*",
      "Sid": "CreateLogGroup"
    },
    {
      "Action": "logs:DescribeLogGroups",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:*",
      "Sid": "DescribeLogGroups"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--AmplifySSRLoggingPolicy-9ceec546-7451-41f6-8409-410781242368" {
  name = "AmplifySSRLoggingPolicy-9ceec546-7451-41f6-8409-410781242368"
  path = "/service-role/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:/aws/amplify/*:log-stream:*",
      "Sid": "PushLogs"
    },
    {
      "Action": "logs:CreateLogGroup",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:/aws/amplify/*",
      "Sid": "CreateLogGroup"
    },
    {
      "Action": "logs:DescribeLogGroups",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:*",
      "Sid": "DescribeLogGroups"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--AmplifySSRLoggingPolicy-c0c3ebab-fdb6-4ed4-a8fb-2ce7dd34f371" {
  name = "AmplifySSRLoggingPolicy-c0c3ebab-fdb6-4ed4-a8fb-2ce7dd34f371"
  path = "/service-role/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:/aws/amplify/*:log-stream:*",
      "Sid": "PushLogs"
    },
    {
      "Action": "logs:CreateLogGroup",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:/aws/amplify/*",
      "Sid": "CreateLogGroup"
    },
    {
      "Action": "logs:DescribeLogGroups",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:353833416626:log-group:*",
      "Sid": "DescribeLogGroups"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--CodePipeline-CodeConnections-eu-west-1-nomaos" {
  description = "Policy used in trust relationship with CodePipeline for CodeConnections Action"
  name        = "CodePipeline-CodeConnections-eu-west-1-nomaos"
  path        = "/service-role/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "codeconnections:UseConnection",
        "codestar-connections:UseConnection"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:codestar-connections:*:353833416626:connection/34fe4280-df27-43a0-b239-95a71c4c1d9b",
        "arn:aws:codeconnections:*:353833416626:connection/34fe4280-df27-43a0-b239-95a71c4c1d9b"
      ]
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--amplify-d3setdk1gwy695-main-branch-467367b8b9-data7552DF31-13E3RJPY8AFZP-amplifyDataAuthRolePolicy01567A5654-kJ3IQgNtXlXZ" {
  name = "amplify-d3setdk1gwy695-main-branch-467367b8b9-data7552DF31-13E3RJPY8AFZP-amplifyDataAuthRolePolicy01567A5654-kJ3IQgNtXlXZ"
  path = "/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": "appsync:GraphQL",
      "Effect": "Allow",
      "Resource": [
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/GuestEntry/*",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/MediaItem/*",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Query/fields/getGuestEntry",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Query/fields/listGuestEntries",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Mutation/fields/createGuestEntry",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Mutation/fields/updateGuestEntry",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Mutation/fields/deleteGuestEntry",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Subscription/fields/onCreateGuestEntry",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Subscription/fields/onUpdateGuestEntry",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Subscription/fields/onDeleteGuestEntry",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Query/fields/getMediaItem",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Query/fields/listMediaItems",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Mutation/fields/createMediaItem",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Mutation/fields/updateMediaItem",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Mutation/fields/deleteMediaItem",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Subscription/fields/onCreateMediaItem",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Subscription/fields/onUpdateMediaItem",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Subscription/fields/onDeleteMediaItem"
      ]
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--amplify-d3setdk1gwy695-main-branch-467367b8b9-data7552DF31-13E3RJPY8AFZP-amplifyDataUnauthRolePolicy01355B9DCF-HIvjT1HkH1Fp" {
  name = "amplify-d3setdk1gwy695-main-branch-467367b8b9-data7552DF31-13E3RJPY8AFZP-amplifyDataUnauthRolePolicy01355B9DCF-HIvjT1HkH1Fp"
  path = "/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": "appsync:GraphQL",
      "Effect": "Allow",
      "Resource": [
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/GuestEntry/*",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/MediaItem/*",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Query/fields/getGuestEntry",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Query/fields/listGuestEntries",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Mutation/fields/createGuestEntry",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Mutation/fields/updateGuestEntry",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Mutation/fields/deleteGuestEntry",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Subscription/fields/onCreateGuestEntry",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Subscription/fields/onUpdateGuestEntry",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Subscription/fields/onDeleteGuestEntry",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Query/fields/getMediaItem",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Query/fields/listMediaItems",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Mutation/fields/createMediaItem",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Mutation/fields/updateMediaItem",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Mutation/fields/deleteMediaItem",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Subscription/fields/onCreateMediaItem",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Subscription/fields/onUpdateMediaItem",
        "arn:aws:appsync:eu-central-1:353833416626:apis/beg42uuyereqjerfalxrk72nmq/types/Subscription/fields/onDeleteMediaItem"
      ]
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--nomaos-bootstrap-dev-workload-boundary" {
  description = "Maximum runtime permissions; each workload still needs a narrowly scoped identity policy"
  name        = "nomaos-bootstrap-dev-workload-boundary"
  path        = "/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutRetentionPolicy",
        "cloudwatch:PutMetricData",
        "sns:Publish",
        "backup:DescribeBackupVault",
        "backup:DescribeRecoveryPoint",
        "backup:ListTags",
        "backup:TagResource",
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchCheckLayerAvailability",
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetRandomPassword",
        "secretsmanager:PutSecretValue",
        "s3:Get*",
        "s3:List*",
        "s3:PutObject",
        "s3:AbortMultipartUpload",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RetireGrant",
        "ec2:Describe*",
        "ec2:CreateSnapshot",
        "ec2:CreateSnapshots",
        "ec2:CopySnapshot",
        "ec2:DeleteSnapshot",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:ModifySnapshotAttribute",
        "ssm:DescribeAssociation",
        "ssm:GetDeployablePatchSnapshotForInstance",
        "ssm:GetDocument",
        "ssm:DescribeDocument",
        "ssm:GetManifest",
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:ListAssociations",
        "ssm:ListInstanceAssociations",
        "ssm:PutInventory",
        "ssm:PutComplianceItems",
        "ssm:PutConfigurePackageResult",
        "ssm:UpdateAssociationStatus",
        "ssm:UpdateInstanceAssociationStatus",
        "ssm:UpdateInstanceInformation",
        "ssmmessages:*",
        "ec2messages:*"
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "RuntimeCapabilitiesOnly"
    },
    {
      "Action": "s3:*",
      "Effect": "Deny",
      "Resource": [
        "arn:aws:s3:::nomaos-tfstate-353833416626-eu-west-1",
        "arn:aws:s3:::nomaos-tfstate-353833416626-eu-west-1/*",
        "arn:aws:s3:::nomaos-tfstate-logs-353833416626-eu-west-1",
        "arn:aws:s3:::nomaos-tfstate-logs-353833416626-eu-west-1/*"
      ],
      "Sid": "NoTerraformState"
    },
    {
      "Action": "kms:*",
      "Effect": "Deny",
      "Resource": "arn:aws:kms:eu-west-1:353833416626:key/31f57b1f-cbde-4aa6-8c6e-18e129c80fb6",
      "Sid": "NoTerraformKey"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

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
