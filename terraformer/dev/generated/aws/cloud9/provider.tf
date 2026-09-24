provider "aws" {
  region = "*"
}

terraform {
	required_providers {
		aws = {
	    version = "~> 5.100.0"
		}
  }
}
