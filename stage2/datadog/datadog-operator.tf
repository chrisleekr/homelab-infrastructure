# https://github.com/DataDog/datadog-operator/blob/main/docs/installation.md
resource "helm_release" "datadog_operator" {
  depends_on = [kubernetes_namespace.datadog, kubernetes_secret.datadog_api_key, kubernetes_secret.datadog_app_key]

  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog-operator"
  namespace  = kubernetes_namespace.datadog.metadata[0].name
  version    = "2.13.1"
  wait       = true
  timeout    = 300

  values = [
    templatefile(
      "${path.module}/templates/datadog-operator-values.tftpl",
      {
        datadog_cluster_name   = var.datadog_cluster_name
        datadog_api_key_secret = kubernetes_secret.datadog_api_key.metadata[0].name
        datadog_app_key_secret = kubernetes_secret.datadog_app_key.metadata[0].name
      }
    )
  ]
}
