resource "aws_iam_user_policy_attachment" "tfer--NomaOS_AWSCloudFormationFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"
  user       = "NomaOS"
}

resource "aws_iam_user_policy_attachment" "tfer--NomaOS_AmazonEC2FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  user       = "NomaOS"
}

resource "aws_iam_user_policy_attachment" "tfer--NomaOS_AmazonECS_FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
  user       = "NomaOS"
}

resource "aws_iam_user_policy_attachment" "tfer--NomaOS_AmazonRekognitionReadOnlyAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRekognitionReadOnlyAccess"
  user       = "NomaOS"
}

resource "aws_iam_user_policy_attachment" "tfer--NomaOS_AmazonS3FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  user       = "NomaOS"
}

resource "aws_iam_user_policy_attachment" "tfer--NomaOS_AmazonSESFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
  user       = "NomaOS"
}

resource "aws_iam_user_policy_attachment" "tfer--NomaOS_AmazonSNSFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
  user       = "NomaOS"
}

resource "aws_iam_user_policy_attachment" "tfer--NomaOS_AmazonSSMReadOnlyAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
  user       = "NomaOS"
}

resource "aws_iam_user_policy_attachment" "tfer--NomaOS_IAMFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
  user       = "NomaOS"
}

resource "aws_iam_user_policy_attachment" "tfer--dolapo_AdministratorAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  user       = "dolapo"
}
