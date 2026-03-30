resource "kubernetes_namespace_v1" "logging" {
  metadata {
    name = "logging"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "homelab"
    }
  }

  lifecycle {
    # Required module: guards against accidental destruction.
    prevent_destroy = true
  }
}
