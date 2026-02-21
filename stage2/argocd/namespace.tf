resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }

  # Required module: guards against accidental destruction. To intentionally destroy, set prevent_destroy = false, apply, then revert.
  lifecycle {
    prevent_destroy = true
  }
}
