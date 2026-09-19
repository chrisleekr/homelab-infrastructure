# Gateway API exposure for the ArgoCD UI and API, replacing the chart's own Ingress.
#
# NOTE: unlike every other migrated host, there is NO AuthorizationPolicy here. ArgoCD is not behind
# oauth2-proxy: it runs its own Auth0 OIDC login, configured in argocd-configmap.tf, which is why the
# host answers 200 rather than an ext_authz login redirect. Adding the CUSTOM policy the other
# modules use would put a second, conflicting login in front of it and break the OIDC callback.
locals {
  argocd_route_slug = replace(var.argocd_domain, ".", "-")

  # Header mutations every route carries. Copied per module deliberately: Gateway API has no
  # gateway-wide header policy, and mesh proxyHeaders alone does not set all of these.
  #   - server: mesh config stops Envoy overwriting it, which leaves the BACKEND value exposed.
  #     Only the route can remove the header.
  #   - x-envoy-peer-metadata and -id: mesh metadataExchangeHeaders IN_MESH did not stop these
  #     reaching a non-injected backend in 1.31. The route strips them.
  #   - x-real-ip: a client-supplied value is forwarded untouched, so every route must overwrite it
  #     or a caller can forge it. The value comes from the trusted client address, which is only
  #     correct because meshConfig sets numTrustedProxies.
  argocd_request_header_filter = {
    type = "RequestHeaderModifier"
    requestHeaderModifier = {
      set = [{
        name  = "X-Real-IP"
        value = "%REQ(X-ENVOY-EXTERNAL-ADDRESS)%"
      }]
      remove = [
        "x-envoy-peer-metadata",
        "x-envoy-peer-metadata-id",
        "x-envoy-decorator-operation",
      ]
    }
  }

  argocd_response_header_filter = {
    type = "ResponseHeaderModifier"
    responseHeaderModifier = {
      set = [
        {
          name  = "Strict-Transport-Security"
          value = "max-age=63072000"
        },
        {
          name  = "Referrer-Policy"
          value = "strict-origin-when-cross-origin"
        },
      ]
      remove = ["server"]
    }
  }
}

# Contributes this host's HTTPS listener to the shared Gateway. The Gateway itself never names this
# host, so enabling or disabling this module is the only edit a cutover needs.
resource "kubectl_manifest" "listener" {
  depends_on = [helm_release.argo_cd]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "ListenerSet"
    metadata = {
      name      = local.argocd_route_slug
      namespace = kubernetes_namespace_v1.argocd.metadata[0].name
    }
    spec = {
      parentRef = {
        name      = var.istio_gateway_name
        namespace = var.istio_gateway_namespace
      }
      listeners = [{
        name     = local.argocd_route_slug
        port     = 443
        protocol = "HTTPS"
        hostname = var.argocd_domain
        tls = {
          mode            = "Terminate"
          certificateRefs = [{ kind = "Secret", name = "argocd-server-tls" }]
        }
        allowedRoutes = {
          namespaces = { from = "Same" }
        }
      }]
    }
  })
}

# Same name and Secret the ingress-shim Certificate used, so the existing valid certificate keeps
# being served while DNS-01 issues a replacement. cert-manager does not adopt across issuers: the
# Secret was issued by letsencrypt-prod, so this re-issues under letsencrypt-gateway.
#
# depends_on the Helm release because that upgrade removes the Ingress, and deleting the Ingress
# garbage-collects the shim-owned Certificate holding this name. The Secret survives: cert-manager
# does not own it unless --enable-certificate-owner-ref is set, which it is not here.
resource "kubectl_manifest" "certificate" {
  depends_on = [helm_release.argo_cd]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "argocd-server-tls"
      namespace = kubernetes_namespace_v1.argocd.metadata[0].name
    }
    spec = {
      secretName = "argocd-server-tls"
      dnsNames   = [var.argocd_domain]
      issuerRef = {
        kind = "ClusterIssuer"
        name = "letsencrypt-gateway"
      }
    }
  })
}

# Attaches to this module's own ListenerSet, not to the Gateway, so it cannot be served before the
# listener exists.
#
# Two ports, one workload. argocd-server is plaintext because argocd-cmd-params-cm sets
# server.insecure: true, so the gateway terminates TLS and forwards cleartext. It serves the UI and gRPC on a single container port, but accepts HTTP/2 only when
# the content type is gRPC: a plain HTTP request over h2c is refused.
#
# Istio picks the upstream protocol from the Service port name, and a gateway forwards HTTP/1.1
# unless that name is http2 or grpc. So port 80, named "http", carries the UI, and port 8080, named
# "http2", carries native gRPC. Pointing everything at either one breaks the other half.
#
# The content type match excludes application/grpc-web on purpose. The CLI sends that with
# --grpc-web over HTTP/1.1, and argocd-server handles it in the HTTP mux, so it belongs on port 80.
resource "kubectl_manifest" "route" {
  depends_on = [kubectl_manifest.listener]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = local.argocd_route_slug
      namespace = kubernetes_namespace_v1.argocd.metadata[0].name
    }
    spec = {
      parentRefs = [{
        group       = "gateway.networking.k8s.io"
        kind        = "ListenerSet"
        name        = local.argocd_route_slug
        sectionName = local.argocd_route_slug
      }]
      hostnames = [var.argocd_domain]
      rules = [
        {
          # More header matches wins on precedence, so gRPC takes this rule and the rest fall
          # through to the catch-all below regardless of the order they are written in.
          matches = [{
            headers = [{
              type  = "RegularExpression"
              name  = "content-type"
              value = "^application/grpc([+][a-zA-Z0-9.-]+)?$"
            }]
          }]
          filters = [
            local.argocd_request_header_filter,
            local.argocd_response_header_filter,
          ]
          backendRefs = [{
            name = "argocd-server"
            port = 8080
          }]
        },
        {
          filters = [
            local.argocd_request_header_filter,
            local.argocd_response_header_filter,
          ]
          backendRefs = [{
            name = "argocd-server"
            port = 80
          }]
        },
      ]
    }
  })
}
