resource "aws_iam_policy" "tfer--AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8" {
  description = "Policy used in trust relationship with CodePipeline for service role"
  name        = "AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8"
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
          "aws:ResourceAccount": "221434544570"
        }
      },
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::codepipeline-eu-west-1-388c27815165-4d9c-97e5-35f4ec8ad1d6"
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
          "aws:ResourceAccount": "221434544570"
        }
      },
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::codepipeline-eu-west-1-388c27815165-4d9c-97e5-35f4ec8ad1d6/*"
      ],
      "Sid": "AllowS3ObjectAccess"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--AmplifySSRLoggingPolicy-227acf59-5d64-413b-b600-1a52d75bec84" {
  name = "AmplifySSRLoggingPolicy-227acf59-5d64-413b-b600-1a52d75bec84"
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
      "Resource": "arn:aws:logs:eu-west-1:221434544570:log-group:/aws/amplify/*:log-stream:*",
      "Sid": "PushLogs"
    },
    {
      "Action": "logs:CreateLogGroup",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:221434544570:log-group:/aws/amplify/*",
      "Sid": "CreateLogGroup"
    },
    {
      "Action": "logs:DescribeLogGroups",
      "Effect": "Allow",
      "Resource": "arn:aws:logs:eu-west-1:221434544570:log-group:*",
      "Sid": "DescribeLogGroups"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--CodePipeline-CodeConnections-eu-west-1-argovesto-api-v8" {
  description = "Policy used in trust relationship with CodePipeline for CodeConnections Action"
  name        = "CodePipeline-CodeConnections-eu-west-1-argovesto-api-v8"
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
        "arn:aws:codestar-connections:*:221434544570:connection/da07fb91-02f9-4552-9d01-837a9366b681",
        "arn:aws:codeconnections:*:221434544570:connection/da07fb91-02f9-4552-9d01-837a9366b681"
      ]
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--CostExplorer" {
  name = "CostExplorer"
  path = "/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": "ce:*",
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "VisualEditor0"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--DMSSecretManagerPolicy-DMSSecretManagerAccessRole-agxdb2DBcredentials" {
  description = "Access to Secret Manager"
  name        = "DMSSecretManagerPolicy-DMSSecretManagerAccessRole-agxdb2DBcredentials"
  path        = "/service-role/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:secretsmanager:eu-west-1:221434544570:secret:agxdb2DBcredentials-26LKpW"
      ],
      "Sid": "AllowDMSSecretsManagerRole"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--DMSSecretManagerPolicy-DMSSecretManagerAccessRole-nomaosDBcredentials" {
  description = "Access to Secret Manager"
  name        = "DMSSecretManagerPolicy-DMSSecretManagerAccessRole-nomaosDBcredentials"
  path        = "/service-role/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:secretsmanager:eu-west-1:221434544570:secret:nomaosDBcredentials-GIwHiK"
      ],
      "Sid": "AllowDMSSecretsManagerRole"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_policy" "tfer--agrovesto-prod-github-deploy-policy" {
  description = "Terraform deploy permissions for the agrovesto-prod stack"
  name        = "agrovesto-prod-github-deploy-policy"
  path        = "/"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "sts:GetCallerIdentity",
        "secretsmanager:*",
        "s3:*",
        "rds:*",
        "logs:*",
        "kms:*",
        "elasticloadbalancing:*",
        "elasticfilesystem:*",
        "ecs:*",
        "ecr:*",
        "ec2:*",
        "acm:*"
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "ManagedServices"
    },
    {
      "Action": [
        "route53domains:List*",
        "route53domains:Get*",
        "route53:*"
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "Route53ZoneManagement"
    },
    {
      "Action": [
        "sts:DecodeAuthorizationMessage",
        "iam:*"
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Sid": "IamForTerraform"
    },
    {
      "Action": "s3:ListBucket",
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::nomaos-tfstate-221434544570-eu-west-1",
      "Sid": "TerraformStateBucket"
    },
    {
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::nomaos-tfstate-221434544570-eu-west-1/*",
      "Sid": "TerraformStateObjects"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

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
