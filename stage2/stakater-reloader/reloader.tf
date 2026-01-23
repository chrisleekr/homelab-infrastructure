resource "helm_release" "reloader" {
  depends_on = [kubernetes_namespace.reloader_namespace]

  name       = "stakater"
  repository = "https://stakater.github.io/stakater-charts"
  chart      = "reloader"
  version    = "2.2.7"
  namespace  = kubernetes_namespace.reloader_namespace.metadata[0].name
  wait       = true
  timeout    = 300

  values = [
    templatefile(
      "${path.module}/templates/reloader-values.tftpl",
      {
      }
    )
  ]
}
