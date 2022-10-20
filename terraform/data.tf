# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
data "aws_caller_identity" "current" {}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_authorization_token
data "aws_ecr_authorization_token" "auth_token" {}

data "aws_ssm_parameter" "s3_bucket" {
  name = "/${var.project_name}/s3_bucket"
}

data "aws_ssm_parameter" "access_key_id" {
  name = "/${var.project_name}/access_key_id"
}

data "aws_ssm_parameter" "secret_access_key" {
  name = "/${var.project_name}/secret_access_key"
}