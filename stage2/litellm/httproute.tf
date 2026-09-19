# Gateway API exposure for LiteLLM, replacing the two nginx Ingresses.
#
# One host serves an open API and a gated admin console. A single route carries every path and the
# gate is expressed per path on the AuthorizationPolicy, so path selection and auth selection are
# separate mechanisms. The Ingress pair could not do that: it split by path at the router, which
# forced both halves onto one TLS secret with only one of them annotated for cert-manager.
#
# Three objects live in this namespace; the AuthorizationPolicy must live in the Gateway's
# namespace, because Istio requires a policy to sit beside the resource its targetRefs names. It is
# still declared here, so it appears and disappears with this module rather than with a central list.
locals {
  litellm_route_slug = replace(var.litellm_domain, ".", "-")

  # Istio matches a trailing * as a raw STRING prefix, so "/ui*" would also match /uixyz. Emitting
  # both the bare path and the "/*" form keeps matching ELEMENT-WISE, so /ui covers /ui/models but
  # never /uixyz. That is also the Ingress pathType Prefix semantics these paths carried before.
  # Ref: https://istio.io/latest/docs/reference/config/security/authorization-policy/ (Rule)
  litellm_gated_path_matches = distinct(flatten([
    for path in var.litellm_ui_paths : [path, "${path}/*"]
  ]))

  # Header mutations every route carries. Copied per module deliberately: Gateway API has no
  # gateway-wide header policy, and mesh proxyHeaders alone does not set all of these.
  #   - server: mesh config stops Envoy overwriting it, which leaves the BACKEND value exposed.
  #     Only the route can remove the header.
  #   - x-envoy-peer-metadata and -id: mesh metadataExchangeHeaders IN_MESH did not stop these
  #     reaching a non-injected backend in 1.31. The route strips them.
  #   - x-real-ip: a client-supplied value is forwarded untouched, so every route must overwrite it
  #     or a caller can forge it. The value comes from the trusted client address, which is only
  #     correct because meshConfig sets numTrustedProxies.
  litellm_request_header_filter = {
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

  litellm_response_header_filter = {
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
  count = var.litellm_enable ? 1 : 0

  depends_on = [helm_release.litellm]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "ListenerSet"
    metadata = {
      name      = local.litellm_route_slug
      namespace = local.litellm_namespace
    }
    spec = {
      parentRef = {
        name      = var.istio_gateway_name
        namespace = var.istio_gateway_namespace
      }
      listeners = [{
        name     = local.litellm_route_slug
        port     = 443
        protocol = "HTTPS"
        hostname = var.litellm_domain
        tls = {
          mode            = "Terminate"
          certificateRefs = [{ kind = "Secret", name = local.litellm_tls_secret_name }]
        }
        allowedRoutes = {
          namespaces = { from = "Same" }
        }
      }]
    }
  })
}

# Issued fresh under letsencrypt-gateway. Unlike the hosts migrated off nginx, this module has never
# served through the gateway, so there is no existing Secret to keep serving during issuance.
resource "kubectl_manifest" "certificate" {
  count = var.litellm_enable ? 1 : 0

  depends_on = [helm_release.litellm]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = local.litellm_tls_secret_name
      namespace = local.litellm_namespace
    }
    spec = {
      secretName = local.litellm_tls_secret_name
      dnsNames   = [var.litellm_domain]
      issuerRef = {
        kind = "ClusterIssuer"
        name = "letsencrypt-gateway"
      }
    }
  })
}

# One rule for every path. The open/gated split lives on the AuthorizationPolicy, not here: the
# backend is the same Service either way, and splitting the route would only duplicate the filters.
#
# SSE token streaming needs no extra configuration. Envoy speaks HTTP/1.1 upstream by default and
# does not buffer responses, which is what the proxy-http-version and proxy-buffering annotations
# bought on nginx. The 50m body cap is not carried over: Envoy streams request bodies and the
# buffer filter is absent from the gateway's chain.
resource "kubectl_manifest" "route" {
  count = var.litellm_enable ? 1 : 0

  # The gate must exist before the route publishes the host and outlive it on destroy, or gated
  # paths serve unauthenticated in between.
  depends_on = [kubectl_manifest.listener, kubectl_manifest.require_auth]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = local.litellm_route_slug
      namespace = local.litellm_namespace
    }
    spec = {
      parentRefs = [{
        group       = "gateway.networking.k8s.io"
        kind        = "ListenerSet"
        name        = local.litellm_route_slug
        sectionName = local.litellm_route_slug
      }]
      hostnames = [var.litellm_domain]
      rules = [{
        filters = [
          local.litellm_request_header_filter,
          local.litellm_response_header_filter,
        ]
        backendRefs = [{
          name = local.litellm_service_name
          port = local.litellm_service_port
        }]
      }]
    }
  })
}

# Gates the console and the introspection routes. action CUSTOM hands the decision to the ext_authz
# provider declared in mesh config, which is oauth2-proxy.
#
# Fails OPEN if litellm_ui_paths is empty, which is the inverse of the omniroute policy: paths here
# name what to gate rather than what to open. The variable's own validation rejects an empty list,
# which is what keeps the console from being published unauthenticated.
#
# No notPaths for the ACME challenge: this host's certificate is issued by DNS-01, so no HTTP
# challenge request ever arrives. An exemption here would be dead config implying otherwise.
resource "kubectl_manifest" "require_auth" {
  count = var.litellm_enable ? 1 : 0

  depends_on = [kubectl_manifest.listener]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "${local.litellm_route_slug}-require-auth"
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
          # Both host forms are needed: the authority carries the port when a client sends one.
          operation = {
            hosts = [var.litellm_domain, "${var.litellm_domain}:*"]
            paths = local.litellm_gated_path_matches
          }
        }]
      }]
    }
  })
}
