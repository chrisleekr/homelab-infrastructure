# CRDs must exist before modules that create ServiceMonitor and related resources.
resource "helm_release" "prometheus_operator_crds" {
  name       = "prometheus-operator-crds"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-operator-crds"
  version    = "31.0.0"
  namespace  = "kube-system"

  # The CRDs predate this release: they were applied with kubectl, so they carry no Helm
  # ownership metadata and adoption fails without this. Harmless once adopted, and a no-op
  # on a fresh cluster.
  take_ownership = true
  wait           = true

  values = [
    yamlencode({
      crds = {
        annotations = {
          "helm.sh/resource-policy" = "keep"
        }
      }
    })
  ]
}
