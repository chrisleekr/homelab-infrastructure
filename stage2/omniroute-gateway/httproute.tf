# Gateway API exposure for OmniRoute.
#
# One host serves an open API and a gated dashboard. A single route carries every path, and the
# gate is expressed per path on the AuthorizationPolicy, so path selection and auth selection are
# separate mechanisms.
#
# Three objects live in this namespace; the AuthorizationPolicy must live in the Gateway's
# namespace, because Istio requires a policy to sit beside the resource its targetRefs names. It is
# still declared here, so it appears and disappears with this module rather than with a central list.
locals {
  omniroute_route_slug = replace(var.omniroute_domain, ".", "-")

  # Istio matches a trailing * as a raw STRING prefix, so "/v1*" would also match /v1beta and
  # exempt a gated path from the gate. Emitting both the bare path and the "/*" form keeps matching
  # ELEMENT-WISE, so /v1 covers /v1/models but never /v1beta.
  # Ref: https://istio.io/latest/docs/reference/config/security/authorization-policy/ (Rule)
  omniroute_public_path_matches = distinct(flatten([
    for path in var.omniroute_public_paths : [path, "${path}/*"]
  ]))

  omniroute_gated_admin_path_matches = distinct(flatten([
    for path in local.omniroute_gated_admin_paths : [path, "${path}/*"]
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
  omniroute_request_header_filter = {
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

  omniroute_response_header_filter = {
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
  count = var.omniroute_enable ? 1 : 0

  depends_on = [helm_release.omniroute]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "ListenerSet"
    metadata = {
      name      = local.omniroute_route_slug
      namespace = local.omniroute_namespace
    }
    spec = {
      parentRef = {
        name      = var.istio_gateway_name
        namespace = var.istio_gateway_namespace
      }
      listeners = [{
        name     = local.omniroute_route_slug
        port     = 443
        protocol = "HTTPS"
        hostname = var.omniroute_domain
        tls = {
          mode            = "Terminate"
          certificateRefs = [{ kind = "Secret", name = local.omniroute_tls_secret_name }]
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
# depends_on the Helm release only for ordering. The shim Certificate of this name is owned by the
# omniroute-ui Ingress, so removing that Ingress garbage-collects it. The Secret survives:
# cert-manager does not own it unless --enable-certificate-owner-ref is set, which it is not here.
resource "kubectl_manifest" "certificate" {
  count = var.omniroute_enable ? 1 : 0

  depends_on = [helm_release.omniroute]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = local.omniroute_tls_secret_name
      namespace = local.omniroute_namespace
    }
    spec = {
      secretName = local.omniroute_tls_secret_name
      dnsNames   = [var.omniroute_domain]
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
# SSE needs no extra configuration. Envoy speaks HTTP/1.1 upstream by default and does not buffer
# responses.
resource "kubectl_manifest" "route" {
  count = var.omniroute_enable ? 1 : 0

  # The gate must exist before the route publishes the host and outlive it on destroy, or gated
  # paths serve unauthenticated in between.
  depends_on = [kubectl_manifest.listener, kubectl_manifest.require_auth]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = local.omniroute_route_slug
      namespace = local.omniroute_namespace
    }
    spec = {
      parentRefs = [{
        group       = "gateway.networking.k8s.io"
        kind        = "ListenerSet"
        name        = local.omniroute_route_slug
        sectionName = local.omniroute_route_slug
      }]
      hostnames = [var.omniroute_domain]
      rules = [{
        filters = [
          local.omniroute_request_header_filter,
          local.omniroute_response_header_filter,
        ]
        backendRefs = [{
          name = local.omniroute_service_name
          port = local.omniroute_service_port
        }]
      }]
    }
  })
}

# Gates the protected paths on this host. action CUSTOM
# hands the decision to the ext_authz provider declared in mesh config, which is oauth2-proxy.
#
# Istio ORs the rules: "A match occurs when at least one rule matches the request". The gate is
# therefore invoked when the path is an admin route, OR when it is not part of the open API surface.
# The admin paths are longer than the open prefixes they sit under, so they are matched
# specifically rather than falling through to the open surface.
#
# No notPaths for the ACME challenge: this host's certificate is issued by DNS-01, so no HTTP
# challenge request ever arrives. An exemption here would be dead config implying otherwise.
resource "kubectl_manifest" "require_auth" {
  count = var.omniroute_enable ? 1 : 0

  depends_on = [kubectl_manifest.listener]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "${local.omniroute_route_slug}-require-auth"
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
      rules = concat(
        # Admin routes on every alias, gated as defense in depth even though they sit beneath an
        # open prefix. Omitted entirely when the suffix list is empty: Istio reads an absent paths
        # field as "any path", so an empty list here would gate the open API too.
        length(local.omniroute_gated_admin_path_matches) > 0 ? [{
          to = [{
            # Both host forms are needed: the authority carries the port when a client sends one.
            operation = {
              hosts = [var.omniroute_domain, "${var.omniroute_domain}:*"]
              paths = local.omniroute_gated_admin_path_matches
            }
          }]
        }] : [],
        # The dashboard, its assets, and every path not explicitly opened. Fails closed: an empty
        # public list leaves notPaths empty, which gates everything.
        [{
          to = [{
            operation = {
              hosts    = [var.omniroute_domain, "${var.omniroute_domain}:*"]
              notPaths = local.omniroute_public_path_matches
            }
          }]
        }],
      )
    }
  })
}
