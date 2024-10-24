resource "kubernetes_namespace" "monitoring_namespace" {
  metadata {
    name = "monitoring"
  }
}
