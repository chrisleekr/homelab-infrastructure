# secret


# Slack notifications stay off until a token is supplied. The token is never handed to
# templatefile: the values file only names the $slack-token key of argocd-notifications-slack-secret,
# so the secret material never reaches the rendered Helm values.
locals {
  argocd_notifications_slack_enabled = var.argocd_notifications_slack_token != ""

  argocd_notifications_subscriptions = [
    for s in var.argocd_notifications_slack_subscriptions : merge(
      {
        triggers   = s.triggers
        recipients = [for c in s.channels : "slack:${c}"]
      },
      s.selector == "" ? {} : { selector = s.selector }
    )
  ]
}

resource "helm_release" "argo_cd" {
  depends_on = [
    kubernetes_namespace_v1.argocd,
    kubernetes_secret_v1.argocd_auth0_oidc_secret,
    kubernetes_secret_v1.argocd_notifications_secret,
    kubernetes_config_map_v1.argocd_rbac_cm
  ]

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "10.3.3"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name
  # Default 0 keeps every revision as a Secret that kube-apiserver holds in memory.
  max_history = 3
  timeout     = 300
  wait        = true

  values = [
    templatefile("${path.module}/templates/argocd-values.tftpl", {
      prometheus_namespace       = var.prometheus_namespace
      argocd_domain              = var.argocd_domain
      argocd_config_repositories = var.argocd_config_repositories
      auth_oauth2_proxy_host     = var.auth_oauth2_proxy_host
      argocd_auth0_domain        = var.argocd_auth0_domain
      argocd_auth0_client_id     = var.argocd_auth0_client_id

      argocd_notifications_slack_enabled = local.argocd_notifications_slack_enabled
      argocd_notifications_subscriptions = local.argocd_notifications_subscriptions
    })
  ]
}
data "kubernetes_secret_v1" "argocd_initial_admin_secret" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
  }

  depends_on = [
    helm_release.argo_cd
  ]
}
