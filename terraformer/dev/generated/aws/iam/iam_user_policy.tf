resource "aws_iam_user_policy" "tfer--NomaOS_amplify" {
  name = "amplify"

  policy = <<POLICY
{
  "Statement": [
    {
      "Action": [
        "amplify:*",
        "appsync:*",
        "cognito-idp:*",
        "cognito-identity:*",
        "dynamodb:*",
        "s3:*",
        "iam:*",
        "logs:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  user = "NomaOS"
}
