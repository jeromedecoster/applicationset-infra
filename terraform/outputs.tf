output "project_name" {
  value = var.project_name
}

output "aws_region" {
  value = var.aws_region
}

output "github_owner" {
  value = var.github_owner
}

output "github_repo_infra" {
  value = var.github_repo_infra
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity#account_id
output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
