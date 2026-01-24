resource "kubernetes_namespace_v1" "datadog" {
  metadata {
    name = "datadog"
  }
}
