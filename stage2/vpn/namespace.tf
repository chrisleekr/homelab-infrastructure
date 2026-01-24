resource "kubernetes_namespace_v1" "vpn_namespace" {
  metadata {
    name = "vpn"
  }
}
