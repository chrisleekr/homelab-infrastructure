# CloudNativePG operator, backing the PostgreSQL that replaces the bundled chart removed
# in GitLab chart 10.0.
#
# Installed into the gitlab namespace so it shares this module's lifecycle. Its CRDs are
# cluster-scoped, so destroying this module removes them cluster-wide; acceptable while
# GitLab is their only consumer.
resource "helm_release" "cloudnative_pg" {
  depends_on = [
    kubernetes_namespace_v1.gitlab
  ]

  name       = "cloudnative-pg"
  repository = "https://cloudnative-pg.io/charts"
  chart      = "cloudnative-pg"
  version    = "0.29.0"
  namespace  = kubernetes_namespace_v1.gitlab.metadata[0].name
  timeout    = 300
  wait       = true
}
