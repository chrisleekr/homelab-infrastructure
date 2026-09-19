# The cluster's only ACME issuer: Let's Encrypt, solved by DNS-01 through Cloudflare.
#
# NOT HTTP-01. The solver HTTPRoute can only attach to the Gateway's own listeners, which means port
# 80, but Cloudflare Tunnel delivers every request to the origin on 443, where the listener comes
# from an app module's ListenerSet and only that module's route is attached. The app therefore
# answers the challenge path with its own page. Pointing the solver at a ListenerSet does not work
# either: cert-manager only supports the experimental XListenerSet behind an unset feature gate, and
# silently ignores a standard-channel ListenerSet parentRef.
#
# The token Secret is created by the cert-manager module, because a ClusterIssuer may only read
# Secrets from cert-manager's cluster resource namespace.
#
# Per-host Certificates are not here: each lives in its backend's namespace, created by the module
# that owns the workload, so the ListenerSet can reference the Secret without a ReferenceGrant.
resource "kubectl_manifest" "acme_issuer" {
  depends_on = [kubectl_manifest.gateway]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-gateway"
    }
    spec = {
      acme = merge(
        var.istio_gateway_acme_email == "" ? {} : { email = var.istio_gateway_acme_email },
        {
          server = var.istio_gateway_acme_server
          privateKeySecretRef = {
            name = "letsencrypt-gateway"
          }
          solvers = [{
            dns01 = {
              cloudflare = {
                apiTokenSecretRef = {
                  name = var.istio_gateway_acme_cloudflare_secret
                  key  = "api-token"
                }
              }
            }
          }]
        }
      )
    }
  })
}
