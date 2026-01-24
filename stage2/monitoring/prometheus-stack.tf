
resource "kubernetes_secret_v1" "frontend_basic_auth" {
  metadata {
    name      = "frontend-basic-auth"
    namespace = kubernetes_namespace_v1.monitoring_namespace.metadata[0].name
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

locals {
  prometheus_rules = fileset("${path.module}/prometheus-rules", "*.tftpl")
}

resource "kubectl_manifest" "prometheus_rules" {
  for_each = { for rule in local.prometheus_rules : rule => rule }

  depends_on = [
    kubernetes_namespace_v1.monitoring_namespace
  ]

  yaml_body = templatefile(
    "${path.module}/prometheus-rules/${each.value}",
    {
      namespace = kubernetes_namespace_v1.monitoring_namespace.metadata[0].name
    }
  )
}

resource "helm_release" "prometheus_operator" {
  depends_on = [
    kubernetes_namespace_v1.monitoring_namespace,
    kubernetes_secret_v1.frontend_basic_auth,
    random_password.grafana_admin_password,
    kubectl_manifest.prometheus_rules
  ]

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "80.13.3"
  namespace  = kubernetes_namespace_v1.monitoring_namespace.metadata[0].name
  timeout    = 360
  wait       = true

  values = [
    templatefile(
      "${path.module}/templates/prometheus-stack-values.tftpl",
      {
        frontend_basic_auth_secret_name = kubernetes_secret_v1.frontend_basic_auth.metadata[0].name
        alertmanager_domain             = var.prometheus_alertmanager_domain
        grafana_domain                  = var.prometheus_grafana_domain
        grafana_admin_password          = random_password.grafana_admin_password.result
        grafana_storage_class           = var.prometheus_grafana_storage_class

        ingress_class_name = var.prometheus_ingress_class_name
        ingress_enable_tls = var.prometheus_ingress_enable_tls

        prometheus_domain              = var.prometheus_prometheus_domain
        persistence_storage_class_name = var.prometheus_persistence_storage_class_name
        persistence_size               = var.prometheus_persistence_size

        alertmanager_slack_channel     = var.prometheus_alertmanager_slack_channel
        alertmanager_slack_credentials = var.prometheus_alertmanager_slack_credentials

        minio_job_bearer_token          = var.prometheus_minio_job_bearer_token
        minio_job_node_bearer_token     = var.prometheus_minio_job_node_bearer_token
        minio_job_bucket_bearer_token   = var.prometheus_minio_job_bucket_bearer_token
        minio_job_resource_bearer_token = var.prometheus_minio_job_resource_bearer_token

        auth_oauth2_proxy_host = var.auth_oauth2_proxy_host
      }
    )
  ]
}
