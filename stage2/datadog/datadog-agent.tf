resource "kubectl_manifest" "datadog_agent" {
  depends_on = [kubernetes_namespace_v1.datadog, kubernetes_secret_v1.datadog_api_key, kubernetes_secret_v1.datadog_app_key]

  yaml_body = templatefile(
    "${path.module}/templates/datadog-agent.tftpl",
    {
      namespace              = kubernetes_namespace_v1.datadog.metadata[0].name
      datadog_site           = var.datadog_site
      datadog_cluster_name   = var.datadog_cluster_name
      datadog_api_key_secret = kubernetes_secret_v1.datadog_api_key.metadata[0].name
      datadog_app_key_secret = kubernetes_secret_v1.datadog_app_key.metadata[0].name
    }
  )
}
