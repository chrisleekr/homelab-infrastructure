resource "kubernetes_namespace_v1" "datadog" {
  metadata {
    name = "datadog"

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
