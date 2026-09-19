# One Gateway for every public hostname. Istio auto-provisions its Deployment and Service as
# <name>-istio in this namespace; that Service name is what a Cloudflare Tunnel route points at.
#
# The HTTPS listeners are deliberately not here. Each app module contributes its own through a
# ListenerSet, so a host's listener, certificate and route appear and disappear with the module that
# owns the workload rather than with a central map that nothing keeps in agreement.
#
# allowedListeners must be set explicitly: its schema default is None, which accepts no ListenerSet.
#
# Every listener carries its own hostname and certificate, and the gateway selects between them by
# SNI. A tunnel route must therefore set Origin Server Name to the hostname, or no filter chain
# matches and TLS fails before any routing happens.
resource "kubectl_manifest" "gateway" {
  depends_on = [
    helm_release.istiod,
    kubernetes_namespace_v1.istio_ingress,
  ]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = var.istio_gateway_name
      namespace = var.istio_gateway_namespace
    }
    spec = {
      gatewayClassName = "istio"

      allowedListeners = {
        namespaces = { from = "All" }
      }

      listeners = [
        # Plain HTTP. The tunnel speaks HTTPS to the gateway, so this listener only serves LAN
        # clients and anything that reaches port 80 directly. It redirects, see routes.tf.
        {
          name     = "http"
          port     = 80
          protocol = "HTTP"
          allowedRoutes = {
            namespaces = { from = "All" }
          }
        }
      ]
    }
  })
}
