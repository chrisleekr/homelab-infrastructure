resource "kubernetes_namespace" "reloader_namespace" {
  metadata {
    name = "reloader"
  }
}
