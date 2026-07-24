# OmniRoute gateway. The chart version tracks appVersion, so omniroute_chart_version and
# omniroute_image_tag must be bumped as a pair.
# Reference: https://github.com/diegosouzapw/OmniRoute
#
# Published Helm chart, served from a plain HTTPS repository (GitHub Pages), not an OCI registry.
#
# This module directory is deliberately named `omniroute-gateway`, not `omniroute`. The helm
# provider resolves `chart = "omniroute"` as a local path relative to the terraform working dir
# (stage2) before falling back to `repository`. A directory named exactly `stage2/omniroute` would
# match, and the provider would try to load this Terraform module as a Helm chart, failing with
# "Chart.yaml file is missing". Keep the directory name different from the chart name.
resource "helm_release" "omniroute" {
  count = var.omniroute_enable ? 1 : 0

  depends_on = [
    kubernetes_namespace_v1.omniroute,
    kubernetes_secret_v1.auth,
  ]

  name       = "omniroute"
  repository = "https://chrisleekr.github.io/helm-charts"
  chart      = "omniroute"
  version    = var.omniroute_chart_version
  namespace  = local.omniroute_namespace
  wait       = true
  timeout    = 600

  values = [
    templatefile(
      "${path.module}/templates/omniroute-values.tftpl",
      {
        image_tag        = var.omniroute_image_tag
        auth_secret_name = local.omniroute_auth_secret_name
        storage_class    = var.omniroute_storage_class_name
        storage_size     = var.omniroute_storage_size
      }
    )
  ]
}
