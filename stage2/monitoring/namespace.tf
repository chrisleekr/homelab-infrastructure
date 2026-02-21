resource "kubernetes_namespace_v1" "monitoring_namespace" {
  metadata {
    name = "monitoring"
  }

  # Required module: guards against accidental destruction. To intentionally destroy, set prevent_destroy = false, apply, then revert.
  lifecycle {
    prevent_destroy = true
  }
}
