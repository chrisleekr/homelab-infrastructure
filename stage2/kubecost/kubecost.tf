resource "kubernetes_namespace" "kubecost" {
  metadata {
    name = "kubecost"
  }
}


resource "kubernetes_secret" "frontend_basic_auth" {
  metadata {
    name      = "frontend-basic-auth"
    namespace = kubernetes_namespace.kubecost.metadata[0].name
  }

  data = {
    auth = base64decode(var.nginx_frontend_basic_auth_base64)
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

# https://github.com/kubecost/cost-analyzer-helm-chart/blob/develop/README.md#config-options
resource "helm_release" "kubecost" {
  depends_on = [kubernetes_namespace.kubecost]

  name       = "cost-analyzer"
  repository = "https://kubecost.github.io/cost-analyzer/"
  chart      = "cost-analyzer"
  namespace  = kubernetes_namespace.kubecost.metadata[0].name
  version    = "2.7.2"
  wait       = true
  timeout    = 300

  values = [
    templatefile(
      "${path.module}/templates/kubecost-values.tftpl",
      {
        auth_oauth2_proxy_host = var.auth_oauth2_proxy_host
        kubecost_token         = var.kubecost_token

        ingress_enable_tls = var.kubecost_ingress_enable_tls
        ingress_class_name = var.kubecost_ingress_class_name

        kubecost_ingress_host           = var.kubecost_ingress_host
        kubecost_basic_auth_secret_name = kubernetes_secret.frontend_basic_auth.metadata[0].name
      }
    )
  ]
}
