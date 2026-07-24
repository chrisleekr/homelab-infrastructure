# Namespace is only created when the module is enabled, to avoid orphaned namespaces.
#
# No default-ServiceAccount patch here. The chart creates its own ServiceAccount with
# automountServiceAccountToken = false (serviceAccount.create = true, automount = false), so the
# pod never gets an API token mounted. There is nothing to patch on the namespace default.
resource "kubernetes_namespace_v1" "omniroute" {
  count = var.omniroute_enable ? 1 : 0

  metadata {
    name = "omniroute"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "homelab"
    }
  }
}
