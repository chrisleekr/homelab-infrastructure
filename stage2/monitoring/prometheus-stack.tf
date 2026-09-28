
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
    random_password.grafana_admin_password,
    kubectl_manifest.prometheus_rules
  ]

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "88.3.0"
  namespace  = kubernetes_namespace_v1.monitoring_namespace.metadata[0].name
  # Default 0 keeps every revision as a Secret that kube-apiserver holds in memory.
  max_history = 3
  timeout     = 360 # 6 minutes for Prometheus and Grafana startup
  wait        = true

  values = [
    templatefile(
      "${path.module}/templates/prometheus-stack-values.tftpl",
      {
        grafana_admin_password = random_password.grafana_admin_password.result

        persistence_storage_class_name = var.prometheus_persistence_storage_class_name
        persistence_size               = var.prometheus_persistence_size

        alertmanager_slack_channel     = var.prometheus_alertmanager_slack_channel
        alertmanager_slack_credentials = var.prometheus_alertmanager_slack_credentials

        minio_job_bearer_token          = var.prometheus_minio_job_bearer_token
        minio_job_node_bearer_token     = var.prometheus_minio_job_node_bearer_token
        minio_job_bucket_bearer_token   = var.prometheus_minio_job_bucket_bearer_token
        minio_job_resource_bearer_token = var.prometheus_minio_job_resource_bearer_token
      }
    )
  ]
}
