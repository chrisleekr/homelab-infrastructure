resource "kubernetes_namespace_v1" "reloader_namespace" {
  metadata {
    name = "reloader"
  }

  # Required module: guards against accidental destruction. To intentionally destroy, set prevent_destroy = false, apply, then revert.
  lifecycle {
    prevent_destroy = true
  }
}
