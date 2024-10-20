resource "kubernetes_namespace" "vpn_namespace" {
  metadata {
    name = "vpn"
  }
}
