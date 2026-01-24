resource "kubernetes_namespace_v1" "logging" {
  metadata {
    name = "logging"
  }
}
