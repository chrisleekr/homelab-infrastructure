# https://github.com/DataDog/datadog-operator/blob/main/docs/installation.md
resource "helm_release" "datadog_operator" {
  depends_on = [kubernetes_namespace_v1.datadog, kubernetes_secret_v1.datadog_api_key, kubernetes_secret_v1.datadog_app_key]

  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog-operator"
  namespace  = kubernetes_namespace_v1.datadog.metadata[0].name
  version    = "2.14.2"
  wait       = true
  timeout    = 300

  values = [
    templatefile(
      "${path.module}/templates/datadog-operator-values.tftpl",
      {
        datadog_cluster_name   = var.datadog_cluster_name
        datadog_site           = var.datadog_site
        datadog_api_key_secret = kubernetes_secret_v1.datadog_api_key.metadata[0].name
        datadog_app_key_secret = kubernetes_secret_v1.datadog_app_key.metadata[0].name
      }
    )
  ]
}
