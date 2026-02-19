# Sealed Secrets controller is conventionally installed in kube-system.
# Using a dedicated namespace for cleaner resource isolation.
resource "kubernetes_namespace_v1" "sealed_secrets_namespace" {
  metadata {
    name = "sealed-secrets"
  }
}
