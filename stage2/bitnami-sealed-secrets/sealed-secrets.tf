# Sealed Secrets controller decrypts SealedSecret CRDs into regular K8s Secrets.
# Reference: https://github.com/bitnami-labs/sealed-secrets
resource "helm_release" "sealed_secrets" {
  depends_on = [kubernetes_namespace_v1.sealed_secrets_namespace]

  name       = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  version    = "2.18.1" # app version 0.35.0, released 2026-02-12
  namespace  = kubernetes_namespace_v1.sealed_secrets_namespace.metadata[0].name
  wait       = true
  timeout    = 300

  values = [
    templatefile(
      "${path.module}/templates/sealed-secrets-values.tftpl",
      {
        key_renewal_period = var.sealed_secrets_key_renewal_period
      }
    )
  ]
}
