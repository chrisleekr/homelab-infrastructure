resource "kubernetes_namespace_v1" "reloader_namespace" {
  metadata {
    name = "reloader"
  }
}
