# https://github.com/tehcyx/terraform-provider-kind
resource "kind_cluster" "cluster" {
  name           = "cluster-sedgioh"
  wait_for_ready = true

  kubeconfig_path = pathexpand("~/.kube/config")

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      # https://github.com/argoproj/argo-helm/blob/17e601148f0325d196e55a77a1b9577c8bbd926d/charts/argo-cd/values.yaml#L1337-L1346
      extra_port_mappings {
        container_port = local.kind_argocd_container_port # 30080
        host_port      = local.kind_localhost_port        # 8443
        listen_address = local.kind_listen_address        # "0.0.0.0"
        protocol       = "TCP"
      }

      extra_port_mappings {
        # see : argocd/website/service.yaml (.spec.ports)
        container_port = 30000
        host_port      = 9000
        listen_address = local.kind_listen_address
        protocol       = "TCP"
      }
    }
  }
}
