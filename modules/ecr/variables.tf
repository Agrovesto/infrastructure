variable "project" {
  type = string
}
variable "repositories" {
  type = set(string)
}
variable "peer_account_id" {
  type = string
}
variable "kms_key_arn" {
  type = string
}
