# Gateway API exposure for Kibana, replacing the nginx Ingress.
#
# Three objects live in this namespace; the AuthorizationPolicy must live in the Gateway's
# namespace, because Istio requires a policy to sit beside the resource its targetRefs names. It is
# still declared here, so it appears and disappears with this module rather than with a central list.
#
# The whole host is gated. Kibana's own login is not used here: the ECK stack issues one elastic
# superuser credential, so oauth2-proxy is the only thing standing in front of it.
locals {
  kibana_route_slug = replace(var.kibana_domain, ".", "-")

  # Header mutations every route carries. Copied per module deliberately: Gateway API has no
  # gateway-wide header policy, and mesh proxyHeaders alone does not set all of these.
  #   - server: mesh config stops Envoy overwriting it, which leaves the BACKEND value exposed.
  #     Only the route can remove the header.
  #   - x-envoy-peer-metadata and -id: mesh metadataExchangeHeaders IN_MESH did not stop these
  #     reaching a non-injected backend in 1.31. The route strips them.
  #   - x-real-ip: a client-supplied value is forwarded untouched, so every route must overwrite it
  #     or a caller can forge it. The value comes from the trusted client address, which is only
  #     correct because meshConfig sets numTrustedProxies.
  kibana_request_header_filter = {
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

  kibana_response_header_filter = {
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
resource "kubectl_manifest" "kibana_listener" {
  depends_on = [null_resource.kibana_ready]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "ListenerSet"
    metadata = {
      name      = local.kibana_route_slug
      namespace = kubernetes_namespace_v1.logging.metadata[0].name
    }
    spec = {
      parentRef = {
        name      = var.istio_gateway_name
        namespace = var.istio_gateway_namespace
      }
      listeners = [{
        name     = local.kibana_route_slug
        port     = 443
        protocol = "HTTPS"
        hostname = var.kibana_domain
        tls = {
          mode            = "Terminate"
          certificateRefs = [{ kind = "Secret", name = "kibana-tls" }]
        }
        allowedRoutes = {
          namespaces = { from = "Same" }
        }
      }]
    }
  })
}

# Issued fresh under letsencrypt-gateway. Unlike the hosts migrated off nginx, this host never had a
# certificate at all: the Ingress left TLS off by default, so there is no Secret to keep serving
# during issuance.
resource "kubectl_manifest" "kibana_certificate" {
  depends_on = [null_resource.kibana_ready]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "kibana-tls"
      namespace = kubernetes_namespace_v1.logging.metadata[0].name
    }
    spec = {
      secretName = "kibana-tls"
      dnsNames   = [var.kibana_domain]
      issuerRef = {
        kind = "ClusterIssuer"
        name = "letsencrypt-gateway"
      }
    }
  })
}

# Attaches to this module's own ListenerSet, not to the Gateway, so it cannot be served before the
# listener exists. kibana-kb-http speaks plain HTTP because the Kibana manifest disables the ECK
# self-signed certificate, so the gateway terminates TLS and forwards cleartext.
resource "kubectl_manifest" "kibana_route" {
  # The gate must exist before the route publishes the host and outlive it on destroy, or gated
  # paths serve unauthenticated in between.
  depends_on = [kubectl_manifest.kibana_listener, kubectl_manifest.kibana_require_auth]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = local.kibana_route_slug
      namespace = kubernetes_namespace_v1.logging.metadata[0].name
    }
    spec = {
      parentRefs = [{
        group       = "gateway.networking.k8s.io"
        kind        = "ListenerSet"
        name        = local.kibana_route_slug
        sectionName = local.kibana_route_slug
      }]
      hostnames = [var.kibana_domain]
      rules = [{
        filters = [
          local.kibana_request_header_filter,
          local.kibana_response_header_filter,
        ]
        backendRefs = [{
          name = "kibana-kb-http"
          port = 5601
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
resource "kubectl_manifest" "kibana_require_auth" {
  depends_on = [kubectl_manifest.kibana_listener]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "${local.kibana_route_slug}-require-auth"
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
            hosts = [var.kibana_domain, "${var.kibana_domain}:*"]
          }
        }]
      }]
    }
  })
}
