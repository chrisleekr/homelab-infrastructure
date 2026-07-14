# ArgoCD Image Updater watches container registries for new image versions and writes the
# resolved digest back to the GitOps repository, which ArgoCD then syncs. This closes the
# "CI pushed a new image under a mutable tag" gap: the rendered manifest never changes, so
# ArgoCD alone can never detect the new build.
#
# Release name is pinned to `argocd-image-updater` so the chart's fullname matches the TLS
# secret name the deployment mounts.
#
# Reference: https://argocd-image-updater.readthedocs.io/en/stable/
resource "helm_release" "argocd_image_updater" {
  depends_on = [
    kubernetes_secret_v1.container_registry_creds,
    kubernetes_secret_v1.argocd_apps_git_creds,
  ]

  name       = "argocd-image-updater"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-image-updater"
  version    = "1.2.4" # app version v1.2.2, released 2026-06-26
  namespace  = var.argocd_namespace
  wait       = true
  timeout    = 300

  values = [
    templatefile(
      "${path.module}/templates/argocd-image-updater-values.tftpl",
      {
        argocd_namespace = var.argocd_namespace
        git_user         = var.argocd_apps_git_username
        git_email        = "argocd-image-updater@noreply.chrislee.local"
        registry_prefix  = var.container_registry_prefix
        registry_api_url = var.container_registry_api_url
      }
    )
  ]
}
