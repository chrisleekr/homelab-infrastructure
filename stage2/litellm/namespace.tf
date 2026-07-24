# Namespace is only created when the module is enabled, to avoid orphaned namespaces.

resource "kubernetes_namespace_v1" "litellm" {
  count = var.litellm_enable ? 1 : 0

  metadata {
    name = "litellm"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "homelab"
    }
  }
}

# The chart sets serviceAccount.create = false, so both the proxy Deployment and the Prisma
# migrations Job render `serviceAccountName: default`. Neither
# calls the Kubernetes API, and the proxy holds every upstream provider key, so keep an API token
# out of them. Patching the namespace default is the only lever here: the chart's pod spec sets no
# automountServiceAccountToken, and the ServiceAccount setting governs when the pod spec is silent.
# The Postgres pod sets the same field directly on its own pod spec (see postgres.tf).
resource "kubernetes_default_service_account_v1" "litellm" {
  count = var.litellm_enable ? 1 : 0

  metadata {
    namespace = local.litellm_namespace
  }

  automount_service_account_token = false
}
