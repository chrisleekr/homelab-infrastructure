# Auth0 OIDC secret

resource "kubernetes_secret_v1" "argocd_auth0_oidc_secret" {

  depends_on = [
    kubernetes_namespace_v1.argocd
  ]
  metadata {
    name      = "argocd-auth0-secret"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name

    labels = {
      # REQUIRED: This label is essential for ArgoCD to access the secret
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  type = "Opaque"

  data = {
    client_secret = var.argocd_auth0_client_secret
  }
}
