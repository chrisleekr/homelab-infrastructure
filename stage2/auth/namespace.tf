resource "kubernetes_namespace" "auth_namespace" {
  metadata {
    name = "auth"
  }
}
