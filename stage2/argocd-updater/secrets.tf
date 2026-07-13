# Registry read credentials. Referenced from registries.conf as
# `secret:<namespace>/<name>#<field>`, where the field value is "username:password".
resource "kubernetes_secret_v1" "container_registry_creds" {
  metadata {
    name      = "container-registry-creds"
    namespace = var.argocd_namespace
  }

  type = "Opaque"

  data = {
    creds = var.container_registry_credentials
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

# Git write-back credentials. image-updater commits the resolved image digest back to
# argocd-apps; ArgoCD then syncs it. Referenced from the ImageUpdater CR as
# `writeBackConfig.method: git:secret:<namespace>/argocd-apps-git-creds`.
resource "kubernetes_secret_v1" "argocd_apps_git_creds" {
  metadata {
    name      = "argocd-apps-git-creds"
    namespace = var.argocd_namespace
  }

  type = "Opaque"

  data = {
    username = var.argocd_apps_git_username
    password = var.argocd_apps_git_password
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}
