resource "helm_release" "reloader" {
  depends_on = [kubernetes_namespace_v1.reloader_namespace]

  name       = "stakater"
  repository = "https://stakater.github.io/stakater-charts"
  chart      = "reloader"
  version    = "2.2.16"
  namespace  = kubernetes_namespace_v1.reloader_namespace.metadata[0].name
  # Default 0 keeps every revision as a Secret that kube-apiserver holds in memory.
  max_history = 3
  wait        = true
  timeout     = 300

  values = [
    templatefile(
      "${path.module}/templates/reloader-values.tftpl",
      {
      }
    )
  ]
}
