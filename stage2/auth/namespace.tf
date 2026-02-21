resource "kubernetes_namespace_v1" "auth_namespace" {
  metadata {
    name = "auth"
  }

  # Required module: guards against accidental destruction. To intentionally destroy, set prevent_destroy = false, apply, then revert.
  lifecycle {
    prevent_destroy = true
  }
}
