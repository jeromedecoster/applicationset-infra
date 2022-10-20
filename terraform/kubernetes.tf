resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [kind_cluster.cluster]
}

resource "kubernetes_namespace" "my_app" {
  metadata {
    name = "my-app"
  }

  depends_on = [kind_cluster.cluster]
}

# using SSH (connexion using git@github.com:xxx/xxx.git)
resource "kubernetes_secret" "git_creds" {
  metadata {
    name      = "git-creds"
    namespace = "argocd"
  }

  data = {
    sshPrivateKey = data.local_file.key_file_pem.content
  }

  depends_on = [
    local_file.key_file_pub,
    kubernetes_namespace.argocd
  ]
}

# used to pull image from private ECR by argocd-image-updater
resource "kubernetes_secret" "aws_ecr_creds" {
  metadata {
    name      = "aws-ecr-creds"
    namespace = "argocd"
  }

  data = {
    creds = "AWS:${data.aws_ecr_authorization_token.auth_token.password}"
  }

  depends_on = [
    kubernetes_namespace.argocd
  ]
}

# used to pull image from private ECR by the deployment manifest
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret#username-and-password
resource "kubernetes_secret" "regcred" {
  metadata {
    name      = "regcred"
    namespace = "my-app"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${local.registry_server}" = {
          "username" = "AWS"
          "password" = data.aws_ecr_authorization_token.auth_token.password
          "auth"     = base64encode("AWS:${data.aws_ecr_authorization_token.auth_token.password}")
        }
      }
    })
  }

  depends_on = [
    kubernetes_namespace.my_app
  ]
}

resource "kubernetes_secret" "mysecret" {
  metadata {
    name      = "mysecret"
    namespace = "my-app"
  }

  data = {
    AWS_S3_BUCKET         = data.aws_ssm_parameter.s3_bucket.value
    AWS_ACCESS_KEY_ID     = data.aws_ssm_parameter.access_key_id.value
    AWS_SECRET_ACCESS_KEY = data.aws_ssm_parameter.secret_access_key.value
  }

  depends_on = [
    kubernetes_namespace.my_app
  ]
}