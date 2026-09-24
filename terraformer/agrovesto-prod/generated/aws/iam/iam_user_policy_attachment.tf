resource "aws_iam_user_policy_attachment" "tfer--NomaOS_AdministratorAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  user       = "NomaOS"
}

resource "aws_iam_user_policy_attachment" "tfer--NomaOS_AmazonRDSFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
  user       = "NomaOS"
}

resource "aws_iam_user_policy_attachment" "tfer--NomaOS_AmazonRekognitionFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRekognitionFullAccess"
  user       = "NomaOS"
}

resource "aws_iam_user_policy_attachment" "tfer--NomaOS_AmazonS3FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  user       = "NomaOS"
}

resource "aws_iam_user_policy_attachment" "tfer--Omolola_AIOpsAssistantIncidentReportPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AIOpsAssistantIncidentReportPolicy"
  user       = "Omolola"
}

resource "aws_iam_user_policy_attachment" "tfer--Omolola_AIOpsAssistantPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AIOpsAssistantPolicy"
  user       = "Omolola"
}

resource "aws_iam_user_policy_attachment" "tfer--Omolola_AIOpsConsoleAdminPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AIOpsConsoleAdminPolicy"
  user       = "Omolola"
}

resource "aws_iam_user_policy_attachment" "tfer--Omolola_AIOpsOperatorAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AIOpsOperatorAccess"
  user       = "Omolola"
}

resource "aws_iam_user_policy_attachment" "tfer--Omolola_AIOpsReadOnlyAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AIOpsReadOnlyAccess"
  user       = "Omolola"
}

resource "aws_iam_user_policy_attachment" "tfer--Omolola_AdministratorAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  user       = "Omolola"
}

resource "aws_iam_user_policy_attachment" "tfer--Omolola_AdministratorAccess-AWSElasticBeanstalk" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-AWSElasticBeanstalk"
  user       = "Omolola"
}

resource "aws_iam_user_policy_attachment" "tfer--Omolola_AdministratorAccess-Amplify" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-Amplify"
  user       = "Omolola"
}

resource "aws_iam_user_policy_attachment" "tfer--Omolola_AlexaForBusinessDeviceSetup" {
  policy_arn = "arn:aws:iam::aws:policy/AlexaForBusinessDeviceSetup"
  user       = "Omolola"
}

resource "aws_iam_user_policy_attachment" "tfer--Omolola_AlexaForBusinessFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AlexaForBusinessFullAccess"
  user       = "Omolola"
}

resource "aws_iam_user_policy_attachment" "tfer--Omolola_AlexaForBusinessGatewayExecution" {
  policy_arn = "arn:aws:iam::aws:policy/AlexaForBusinessGatewayExecution"
  user       = "Omolola"
}

resource "aws_iam_user_policy_attachment" "tfer--dolapo_AdministratorAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  user       = "dolapo"
}
