
resource "kubernetes_secret" "datadog_api_key" {
  metadata {
    name      = "datadog-api-key"
    namespace = kubernetes_namespace.datadog.metadata[0].name
  }

  data = {
    api-key = var.datadog_api_key
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}


resource "kubernetes_secret" "datadog_app_key" {
  metadata {
    name      = "datadog-app-key"
    namespace = kubernetes_namespace.datadog.metadata[0].name
  }

  data = {
    app-key = var.datadog_app_key
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}
