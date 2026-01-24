resource "kubernetes_namespace_v1" "monitoring_namespace" {
  metadata {
    name = "monitoring"
  }
}
