resource "kubernetes_namespace_v1" "vpn_namespace" {
  metadata {
    name = "vpn"
  }

  # Required module: guards against accidental destruction. To intentionally destroy, set prevent_destroy = false, apply, then revert.
  lifecycle {
    prevent_destroy = true
  }
}
