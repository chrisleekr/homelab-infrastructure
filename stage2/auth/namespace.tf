resource "kubernetes_namespace_v1" "auth_namespace" {
  metadata {
    name = "auth"
  }
}
