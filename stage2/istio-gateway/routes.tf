# HTTP to HTTPS for anything arriving on port 80.
#
# No hostnames, so it covers every host the gateway serves and needs no edit when a module joins.
#
# Per-host HTTPRoutes are not here: they live in the module that owns the backend.
resource "kubectl_manifest" "https_redirect" {
  depends_on = [kubectl_manifest.gateway]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "https-redirect"
      namespace = var.istio_gateway_namespace
    }
    spec = {
      parentRefs = [{
        name        = var.istio_gateway_name
        namespace   = var.istio_gateway_namespace
        sectionName = "http"
      }]
      rules = [{
        filters = [{
          type = "RequestRedirect"
          requestRedirect = {
            scheme     = "https"
            statusCode = 301
          }
        }]
      }]
    }
  })
}
