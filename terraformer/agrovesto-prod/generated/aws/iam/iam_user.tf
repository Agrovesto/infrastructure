resource "aws_iam_user" "tfer--AIDATHDUHAG5B74A3ND4H" {
  force_destroy = "false"
  name          = "Omolola"
  path          = "/"
}

resource "aws_iam_user" "tfer--AIDATHDUHAG5D7M75T5UL" {
  force_destroy = "false"
  name          = "dolapo"
  path          = "/"
}

resource "aws_iam_user" "tfer--AIDATHDUHAG5ESMQUUBAA" {
  force_destroy = "false"
  name          = "NomaOS"
  path          = "/"

  tags = {
    AKIATHDUHAG5BW5FH6GE = "To access AWS services"
  }

  tags_all = {
    AKIATHDUHAG5BW5FH6GE = "To access AWS services"
  }
}
