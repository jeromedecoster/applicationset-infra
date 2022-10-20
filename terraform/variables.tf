variable "project_name" {
  default = ""
}

variable "module_name" {
  default = ""
}

variable "aws_region" {
  default = ""
}

variable "github_owner" {
  default = ""
}

variable "github_token" {
  default   = ""
  sensitive = true
}

variable "github_repo_infra" {
  default = ""
}

variable "github_repo_storage" {
  default = ""
}

variable "github_repo_convert" {
  default = ""
}

variable "github_repo_website" {
  default = ""
}