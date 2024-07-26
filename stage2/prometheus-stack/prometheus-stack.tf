resource "kubernetes_namespace" "prometheus_namespace" {
  metadata {
    name = "prometheus"
  }
}

resource "kubernetes_secret" "frontend_basic_auth" {
  metadata {
    name      = "frontend-basic-auth"
    namespace = kubernetes_namespace.prometheus_namespace.metadata[0].name
  }

  data = {
    auth = base64decode(var.nginx_frontend_basic_auth_base64)
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "random_password" "grafana_admin_password" {
  length  = 16
  special = false
}


resource "helm_release" "prometheus_operator" {
  depends_on = [
    kubernetes_namespace.prometheus_namespace,
    kubernetes_secret.frontend_basic_auth,
    random_password.grafana_admin_password
  ]

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "61.3.2"
  namespace  = "prometheus"
  timeout    = 360

  values = [
    templatefile(
      "${path.module}/templates/prometheus-stack-values.tftpl",
      {
        frontend_basic_auth_secret_name = kubernetes_secret.frontend_basic_auth.metadata[0].name
        alertmanager_domain             = var.prometheus_alertmanager_domain
        grafana_domain                  = var.prometheus_grafana_domain
        grafana_admin_password          = random_password.grafana_admin_password.result
        grafana_storage_class           = var.prometehus_grafana_storage_class
        ingress_class_name              = var.prometheus_ingress_class_name
        prometheus_domain               = var.prometheus_prometheus_domain
        persistence_storage_class_name  = var.prometheus_persistence_storage_class_name
      }
    )
  ]
}
