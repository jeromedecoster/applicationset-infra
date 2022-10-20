terraform {
  required_providers {
    # https://registry.terraform.io/providers/hashicorp/aws/latest
    aws = {
      source = "hashicorp/aws"
      # https://jubianchi.github.io/semver-check/#/~%3E%204.31/4.34
      # >= 4.31.0 <5.0.0
      version = "~> 4.31"
    }

    # https://registry.terraform.io/providers/hashicorp/null/latest
    null = {
      source = "hashicorp/null"
      # https://jubianchi.github.io/semver-check/#/~%3E%203.1/3.4
      # >= 3.1.0 <4.0.0
      version = "~> 3.1"
    }

    # https://registry.terraform.io/providers/hashicorp/null/latest
    local = {
      source = "hashicorp/local"
      # https://jubianchi.github.io/semver-check/#/~%3E%202.2/2.5
      # >= 2.2.0 <3.0.0
      version = "~> 2.2"
    }

    # https://registry.terraform.io/providers/hashicorp/tls/latest
    tls = {
      source = "hashicorp/tls"
      # https://jubianchi.github.io/semver-check/#/~%3E%204.0/4.4
      # >= 4.0.0 <5.0.0
      version = "~> 4.0"
    }

    # https://registry.terraform.io/providers/hashicorp/helm/latest
    helm = {
      source = "hashicorp/helm"
      # >= 2.7.0 <3.0.0
      version = "~> 2.7"
    }

    # https://registry.terraform.io/providers/hashicorp/kubernetes/latest
    kubernetes = {
      source = "hashicorp/kubernetes"
      # >= 2.14.0 <3.0.0
      version = "~> 2.14"
    }

    # https://registry.terraform.io/providers/gavinbunney/kubectl/latest
    kubectl = {
      source = "gavinbunney/kubectl"
      # >= 1.14.0 <2.0.0
      version = "~> 1.14"
    }

    # https://registry.terraform.io/providers/integrations/github/latest
    github = {
      source = "integrations/github"
      # https://jubianchi.github.io/semver-check/#/~%3E%205.2/5.5
      # >= 5.2.0 <6.0.0
      version = "~> 5.2"
    }

    # https://registry.terraform.io/providers/tehcyx/kind/latest
    # https://github.com/tehcyx/terraform-provider-kind
    kind = {
      source = "tehcyx/kind"
      # https://jubianchi.github.io/semver-check/#/~%3E%200.0.14/0.1.0
      # >= 0.0.14 < 0.1.0
      version = "~> 0.0.14"
    }

    # https://registry.terraform.io/providers/oboukili/argocd/latest
    # https://github.com/oboukili/terraform-provider-argocd
    argocd = {
      source = "oboukili/argocd"
      # >= 3.2.0 <4.0.0
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# https://registry.terraform.io/providers/integrations/github/latest/docs
provider "github" {
  owner = var.github_owner
  token = var.github_token
}

provider "kubernetes" {
  # /!\ important /!\
  # if the cluster is created in terraform (and not already active from outside), do not use :
  # config_path = pathexpand("~/.kube/config")
  # in the providers (provider kubernetes, helm, argocd) !
  # because the provider initialization is done EARLY and at that time the ~/.kube/config file
  # does not yet contain the information.
  # you will receive these errors :
  # Error: Kubernetes cluster unreachable: invalid configuration: no configuration has been provided, try setting KUBERNETES_MASTER
  # Error: Post "http://localhost/api/v1/namespaces": dial tcp 127.0.0.1:80: connect: connection refused

  # also, the block `provider` does not accept the `depends_on` parameter
  # we can't write things like :
  # depends_on = [ kind_cluster.cluster ]

  host                   = kind_cluster.cluster.endpoint
  client_certificate     = kind_cluster.cluster.client_certificate
  client_key             = kind_cluster.cluster.client_key
  cluster_ca_certificate = kind_cluster.cluster.cluster_ca_certificate
}

# Error: Kubernetes cluster unreachable: invalid configuration: no configuration has been provided
provider "helm" {
  kubernetes {
    # /!\ important /!\
    # see the note `provider "kubernetes"`
    host                   = kind_cluster.cluster.endpoint
    client_certificate     = kind_cluster.cluster.client_certificate
    client_key             = kind_cluster.cluster.client_key
    cluster_ca_certificate = kind_cluster.cluster.cluster_ca_certificate
  }
}

provider "argocd" {
  server_addr = "${local.kind_listen_address}:${local.kind_localhost_port}"
  username    = "admin"
  password    = data.kubernetes_secret.argocd_secret.data.password

  # port_forward                = true
  # port_forward_with_namespace = "argocd"

  # Error: Failed to init clients
  # x509: cannot validate certificate for 0.0.0.0 because it doesn't contain any IP SANs
  insecure = true

  # grpc_web = true

  kubernetes {
    # /!\ important /!\
    # see the note `provider "kubernetes"`
    host                   = kind_cluster.cluster.endpoint
    client_certificate     = kind_cluster.cluster.client_certificate
    client_key             = kind_cluster.cluster.client_key
    cluster_ca_certificate = kind_cluster.cluster.cluster_ca_certificate
  }
}