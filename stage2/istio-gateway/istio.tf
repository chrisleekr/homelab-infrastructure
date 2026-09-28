# Istio control plane, gateway-only. Two charts: base installs the CRDs and cluster roles, istiod
# is the control plane itself. No istio-cni and no gateway chart: each Gateway resource
# auto-provisions its own Deployment and Service, named <gateway>-istio.
resource "helm_release" "istio_base" {
  depends_on = [
    kubernetes_namespace_v1.istio_system,
    kubectl_manifest.gateway_api_crds,
  ]

  name       = "istio-base"
  repository = var.istio_gateway_chart_repository
  chart      = "base"
  version    = var.istio_gateway_version
  namespace  = var.istio_gateway_control_plane_namespace
  # Default 0 keeps every revision as a Secret that kube-apiserver holds in memory.
  max_history = 3
  timeout     = 300
  wait        = true
}

resource "helm_release" "istiod" {
  depends_on = [helm_release.istio_base]

  name       = "istiod"
  repository = var.istio_gateway_chart_repository
  chart      = "istiod"
  version    = var.istio_gateway_version
  namespace  = var.istio_gateway_control_plane_namespace
  # Default 0 keeps every revision as a Secret that kube-apiserver holds in memory.
  max_history = 3
  timeout     = 600
  wait        = true

  values = [
    templatefile(
      "${path.module}/templates/istiod-values.tftpl",
      {
        istiod_cpu_request    = var.istio_gateway_istiod_requests.cpu
        istiod_memory_request = var.istio_gateway_istiod_requests.memory
        proxy_cpu_request     = var.istio_gateway_proxy_requests.cpu
        proxy_memory_request  = var.istio_gateway_proxy_requests.memory
        num_trusted_proxies   = var.istio_gateway_num_trusted_proxies
        ext_authz_service     = var.istio_gateway_ext_authz_service
        ext_authz_port        = var.istio_gateway_ext_authz_port
      }
    )
  ]
}
