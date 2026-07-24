# LiteLLM proxy. The chart version tracks appVersion, so litellm_chart_version and
# litellm_image_tag must be bumped as a pair.
# Reference: https://github.com/BerriAI/litellm/tree/main/deploy/charts/litellm-helm
#
# For an OCI registry, `repository` is the registry path WITHOUT the chart name.
resource "helm_release" "litellm" {
  count = var.litellm_enable ? 1 : 0

  depends_on = [
    kubernetes_namespace_v1.litellm,
    # Must land before any chart pod is scheduled, or the proxy and the migrations Job start with an
    # API token mounted.
    kubernetes_default_service_account_v1.litellm,
    kubernetes_secret_v1.masterkey,
    kubernetes_secret_v1.env,
    kubernetes_secret_v1.db,
    kubernetes_stateful_set_v1.postgres,
  ]

  name       = "litellm"
  repository = "oci://ghcr.io/berriai"
  chart      = "litellm-helm"
  version    = var.litellm_chart_version
  namespace  = local.litellm_namespace
  wait       = true
  timeout    = 600

  values = [
    templatefile(
      "${path.module}/templates/litellm-values.tftpl",
      {
        replicas              = var.litellm_replicas
        image_tag             = var.litellm_image_tag
        service_name          = local.litellm_service_name
        db_name               = local.litellm_db_name
        masterkey_secret_name = kubernetes_secret_v1.masterkey[0].metadata[0].name
        env_secret_name       = kubernetes_secret_v1.env[0].metadata[0].name
        db_secret_name        = kubernetes_secret_v1.db[0].metadata[0].name
        postgres_service_name = kubernetes_service_v1.postgres[0].metadata[0].name
      }
    )
  ]
}
