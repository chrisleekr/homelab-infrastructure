# Auth0 OIDC RBAC configmap
resource "kubernetes_config_map_v1" "argocd_rbac_cm" {

  depends_on = [
    kubernetes_namespace_v1.argocd
  ]
  metadata {
    name      = "argocd-rbac-cm"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name

    labels = {
      # REQUIRED: This label is essential for ArgoCD to access the secret
      "app.kubernetes.io/component" = "server"
      "app.kubernetes.io/instance"  = "argocd"
      "app.kubernetes.io/name"      = "argocd-rbac-cm"
      "app.kubernetes.io/part-of"   = "argocd"
    }
  }

  data = {
    "policy.default"   = var.argocd_rbac_policy_default
    "policy.csv"       = var.argocd_rbac_policy_csv
    "scopes"           = "[openid, profile, email, https://${var.auth_oauth2_proxy_host}/groups]"
    "policy.matchMode" = "glob"
  }
}
