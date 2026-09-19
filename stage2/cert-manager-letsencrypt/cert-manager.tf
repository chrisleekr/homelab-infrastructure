resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = "cert-manager"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "homelab"
    }
  }

  # Required module: guards against accidental destruction. To intentionally destroy, set prevent_destroy = false, apply, then revert.
  lifecycle {
    prevent_destroy = true
  }
}
resource "helm_release" "cert_manager" {
  depends_on = [
    kubernetes_namespace_v1.cert_manager
  ]

  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.21.2"
  namespace  = kubernetes_namespace_v1.cert_manager.metadata[0].name
  timeout    = 300
  wait       = true

  values = [file("${path.module}/cert-manager-values.tftpl")]
}

# Cloudflare token for the DNS-01 solver. It lives here, not in the istio-gateway module, because a
# ClusterIssuer may only read Secrets from cert-manager's cluster resource namespace. The gateway
# ClusterIssuer references it by name, so the name is part of the contract between the two modules.
resource "kubernetes_secret_v1" "cloudflare_api_token" {
  count = var.cert_manager_cloudflare_api_token == "" ? 0 : 1

  depends_on = [helm_release.cert_manager]

  metadata {
    name      = "cloudflare-api-token"
    namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name
  }

  data = {
    "api-token" = var.cert_manager_cloudflare_api_token
  }
}
