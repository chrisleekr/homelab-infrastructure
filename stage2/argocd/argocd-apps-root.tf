# Root Application for the central argocd-apps repo.
# Only created when argocd_apps_repo_url is set.
# Watches applicationsets/ directory and auto-syncs ApplicationSet manifests.
# Reference: https://argo-cd.readthedocs.io/en/latest/operator-manual/cluster-bootstrapping/
resource "kubernetes_manifest" "argocd_apps_root" {
  count      = var.argocd_apps_repo_url != "" ? 1 : 0
  depends_on = [helm_release.argo_cd]

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"

    metadata = {
      name      = "argocd-apps-root"
      namespace = kubernetes_namespace_v1.argocd.metadata[0].name
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }

    spec = {
      project = "default"

      source = {
        repoURL        = var.argocd_apps_repo_url
        targetRevision = "HEAD"
        path           = "applicationsets"
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "RespectIgnoreDifferences=true"
        ]
      }

      ignoreDifferences = [
        {
          group = "*"
          kind  = "Application"
          jsonPointers = [
            "/spec/syncPolicy/automated",
            "/metadata/annotations/argocd.argoproj.io~1refresh",
            "/operation"
          ]
        }
      ]
    }
  }
}
