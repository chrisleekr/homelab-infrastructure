
resource "kubectl_manifest" "datadog_agent" {
  depends_on = [kubernetes_namespace.datadog, kubernetes_secret.datadog_api_key, kubernetes_secret.datadog_app_key]

  yaml_body = templatefile(
    "${path.module}/templates/datadog-agent.tftpl",
    {
      namespace              = kubernetes_namespace.datadog.metadata[0].name
      datadog_cluster_name   = var.datadog_cluster_name
      datadog_api_key_secret = kubernetes_secret.datadog_api_key.metadata[0].name
      datadog_app_key_secret = kubernetes_secret.datadog_app_key.metadata[0].name
    }
  )
}
