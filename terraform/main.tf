locals {
  # https://www.terraform.io/language/expressions/references#filesystem-and-workspace-info
  # target the $PROJECT_DIR
  project_dir = abspath("${path.root}/..")

  account_id = data.aws_caller_identity.current.account_id

  key_file_pub = "${local.project_dir}/${var.module_name}.pub"
  key_file_pem = "${local.project_dir}/${var.module_name}.pem"

  # kubeconfig_path = pathexpand("~/.kube/config")

  # /!\ by default, argo-server service is :
  # - type : ClusterIP
  # - http port : 80
  # - https: 443
  # if `server.service.type` is set to "NodePort" now service become :
  # - type : NodePort
  # - http port : 30080
  # - https: 30443
  # https://github.com/argoproj/argo-helm/blob/17e601148f0325d196e55a77a1b9577c8bbd926d/charts/argo-cd/values.yaml#L1337-L1346
  kind_argocd_container_port = 30080
  kind_localhost_port        = 8443
  kind_listen_address        = "0.0.0.0"

  registry_server = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  template_vars = {
    github_repo_infra  = var.github_repo_infra
    storage_repository = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/as-storage"
    convert_repository = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/as-convert"
    website_repository = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/as-website"
  }
}

resource "null_resource" "env-file" {

  triggers = {
    everytime = uuid()
  }

  provisioner "local-exec" {
    command = "scripts/env-file.sh .env AWS_ACCOUNT_ID KIND_LISTEN_ADDRESS KIND_LOCALHOST_PORT"

    working_dir = local.project_dir

    environment = {
      AWS_ACCOUNT_ID      = data.aws_caller_identity.current.account_id
      KIND_LISTEN_ADDRESS = local.kind_listen_address
      KIND_LOCALHOST_PORT = local.kind_localhost_port
    }
  }
}
