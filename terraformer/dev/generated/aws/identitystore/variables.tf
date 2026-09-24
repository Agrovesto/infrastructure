data "terraform_remote_state" "identitystore" {
  backend = "local"

  config = {
    path = "../../../generated/aws/identitystore/terraform.tfstate"
  }
}
