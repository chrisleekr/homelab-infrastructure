# Gateway API exposure for the Kubecost dashboard, replacing the chart's own Ingress.
#
# This module has no enable flag, so the host is always exposed. Three objects live in this
# namespace; the AuthorizationPolicy must live in the Gateway's namespace, because Istio requires a
# policy to sit beside the resource its targetRefs names. It is still declared here, so it appears
# and disappears with this module rather than with a central list.
locals {
  kubecost_route_slug = replace(var.kubecost_ingress_host, ".", "-")

  # Header mutations every route carries. Copied per module deliberately: Gateway API has no
  # gateway-wide header policy, and mesh proxyHeaders alone does not set all of these.
  #   - server: mesh config stops Envoy overwriting it, which leaves the BACKEND value exposed.
  #     Only the route can remove the header.
  #   - x-envoy-peer-metadata and -id: mesh metadataExchangeHeaders IN_MESH did not stop these
  #     reaching a non-injected backend in 1.31. The route strips them.
  #   - x-real-ip: a client-supplied value is forwarded untouched, so every route must overwrite it
  #     or a caller can forge it. The value comes from the trusted client address, which is only
  #     correct because meshConfig sets numTrustedProxies.
  kubecost_request_header_filter = {
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

  kubecost_response_header_filter = {
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
  depends_on = [helm_release.kubecost]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "ListenerSet"
    metadata = {
      name      = local.kubecost_route_slug
      namespace = kubernetes_namespace_v1.kubecost.metadata[0].name
    }
    spec = {
      parentRef = {
        name      = var.istio_gateway_name
        namespace = var.istio_gateway_namespace
      }
      listeners = [{
        name     = local.kubecost_route_slug
        port     = 443
        protocol = "HTTPS"
        hostname = var.kubecost_ingress_host
        tls = {
          mode            = "Terminate"
          certificateRefs = [{ kind = "Secret", name = "kubecost-tls" }]
        }
        allowedRoutes = {
          namespaces = { from = "Same" }
        }
      }]
    }
  })
}

# Same name and Secret the ingress-shim Certificate used, so the existing valid certificate is
# adopted and the listener serves it the moment it programs, with no HTTP-01 round trip at cutover.
#
# depends_on the Helm release because that upgrade removes the Ingress, and deleting the Ingress
# garbage-collects the shim-owned Certificate holding this name. The Secret survives: cert-manager
# does not own it unless --enable-certificate-owner-ref is set, which it is not here.
resource "kubectl_manifest" "certificate" {
  depends_on = [helm_release.kubecost]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "kubecost-tls"
      namespace = kubernetes_namespace_v1.kubecost.metadata[0].name
    }
    spec = {
      secretName = "kubecost-tls"
      dnsNames   = [var.kubecost_ingress_host]
      issuerRef = {
        kind = "ClusterIssuer"
        name = "letsencrypt-gateway"
      }
    }
  })
}

# Attaches to this module's own ListenerSet, not to the Gateway, so it cannot be served before the
# listener exists.
resource "kubectl_manifest" "route" {
  # The gate must exist before the route publishes the host and outlive it on destroy, or gated
  # paths serve unauthenticated in between.
  depends_on = [kubectl_manifest.listener, kubectl_manifest.require_auth]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = local.kubecost_route_slug
      namespace = kubernetes_namespace_v1.kubecost.metadata[0].name
    }
    spec = {
      parentRefs = [{
        group       = "gateway.networking.k8s.io"
        kind        = "ListenerSet"
        name        = local.kubecost_route_slug
        sectionName = local.kubecost_route_slug
      }]
      hostnames = [var.kubecost_ingress_host]
      rules = [{
        filters = [
          local.kubecost_request_header_filter,
          local.kubecost_response_header_filter,
        ]
        backendRefs = [{
          name = "cost-analyzer-frontend"
          port = 9090
        }]
      }]
    }
  })
}

# Requires an authenticated session for this host. action CUSTOM hands the decision to the
# ext_authz provider declared in mesh config, which is oauth2-proxy.
#
# No notPaths for the ACME challenge: this host's certificate is issued by DNS-01, so no HTTP
# challenge request ever arrives. An exemption here would be dead config implying otherwise.
resource "kubectl_manifest" "require_auth" {
  depends_on = [kubectl_manifest.listener]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "${local.kubecost_route_slug}-require-auth"
      namespace = var.istio_gateway_namespace
    }
    spec = {
      targetRefs = [{
        group = "gateway.networking.k8s.io"
        kind  = "Gateway"
        name  = var.istio_gateway_name
      }]
      action = "CUSTOM"
      provider = {
        name = "oauth2-proxy"
      }
      rules = [{
        to = [{
          # Both forms are needed: the authority carries the port when a client sends one.
          operation = {
            hosts = [var.kubecost_ingress_host, "${var.kubecost_ingress_host}:*"]
          }
        }]
      }]
    }
  })
}
