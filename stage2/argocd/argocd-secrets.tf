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

# A distinct name avoids transferring ownership of the chart's default notifications Secret.
resource "kubernetes_secret_v1" "argocd_notifications_secret" {
  count = var.argocd_notifications_slack_token != "" ? 1 : 0

  depends_on = [
    kubernetes_namespace_v1.argocd
  ]

  metadata {
    name      = "argocd-notifications-slack-secret"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name

    labels = {
      # Chart convention. The controller finds this Secret by name, not by label.
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  type = "Opaque"

  data = {
    slack-token = var.argocd_notifications_slack_token
  }
}
