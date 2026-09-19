# Gateway API exposure for the three kube-prometheus-stack UIs.
#
# One module owns three hosts, so every object is built with for_each rather than copied per host.
# The header filters are declared once here for the same reason: they are what the backends
# expect, and a route that omits them fails silently.
#
# Three objects per host live in this namespace; the AuthorizationPolicy must live in the Gateway's
# namespace, because Istio requires a policy to sit beside the resource its targetRefs names. It is
# still declared here, so it appears and disappears with this module rather than with a central list.
locals {
  # Backend service names are the Helm release name plus the component, which is how the chart names
  # them. Ports are the chart's service ports, not the container ports. Each tls_secret keeps the
  # name its ingress-shim Certificate already used, so the existing certificate stays in place while
  # DNS-01 issues a replacement.
  monitoring_gateway_hosts = {
    grafana = {
      host       = var.prometheus_grafana_domain
      service    = "${helm_release.prometheus_operator.name}-grafana"
      port       = 80
      tls_secret = "grafana-general-tls"
    }
    prometheus = {
      host       = var.prometheus_prometheus_domain
      service    = "${helm_release.prometheus_operator.name}-prometheus"
      port       = 9090
      tls_secret = "prometheus-general-tls"
    }
    alertmanager = {
      host       = var.prometheus_alertmanager_domain
      service    = "${helm_release.prometheus_operator.name}-alertmanager"
      port       = 9093
      tls_secret = "alertmanager-general-tls"
    }
  }

  monitoring_route_slugs = {
    for key, cfg in local.monitoring_gateway_hosts : key => replace(cfg.host, ".", "-")
  }

  # Header mutations every route carries. Gateway API has no gateway-wide header policy, and mesh
  # proxyHeaders alone does not set all of these.
  #   - server: mesh config stops Envoy overwriting it, which leaves the BACKEND value exposed.
  #     Only the route can remove the header.
  #   - x-envoy-peer-metadata and -id: mesh metadataExchangeHeaders IN_MESH did not stop these
  #     reaching a non-injected backend in 1.31. The route strips them.
  #   - x-real-ip: a client-supplied value is forwarded untouched, so every route must overwrite it
  #     or a caller can forge it. The value comes from the trusted client address, which is only
  #     correct because meshConfig sets numTrustedProxies.
  monitoring_request_header_filter = {
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

  monitoring_response_header_filter = {
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

# Contributes each host's HTTPS listener to the shared Gateway. The Gateway itself never names these
# hosts, so enabling or disabling this module is the only edit a cutover needs.
resource "kubectl_manifest" "listener" {
  for_each = local.monitoring_gateway_hosts

  depends_on = [helm_release.prometheus_operator]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "ListenerSet"
    metadata = {
      name      = local.monitoring_route_slugs[each.key]
      namespace = kubernetes_namespace_v1.monitoring_namespace.metadata[0].name
    }
    spec = {
      parentRef = {
        name      = var.istio_gateway_name
        namespace = var.istio_gateway_namespace
      }
      listeners = [{
        name     = local.monitoring_route_slugs[each.key]
        port     = 443
        protocol = "HTTPS"
        hostname = each.value.host
        tls = {
          mode            = "Terminate"
          certificateRefs = [{ kind = "Secret", name = each.value.tls_secret }]
        }
        allowedRoutes = {
          namespaces = { from = "Same" }
        }
      }]
    }
  })
}

# Same name and Secret the ingress-shim Certificate used, so the existing valid certificate keeps
# being served while DNS-01 issues a replacement. cert-manager does not adopt across issuers: these
# Secrets were issued by letsencrypt-prod, so each re-issues under letsencrypt-gateway.
#
# depends_on the Helm release because that upgrade removes the Ingresses, and deleting an Ingress
# garbage-collects the shim-owned Certificate holding its name. The Secret survives: cert-manager
# does not own it unless --enable-certificate-owner-ref is set, which it is not here.
resource "kubectl_manifest" "certificate" {
  for_each = local.monitoring_gateway_hosts

  depends_on = [helm_release.prometheus_operator]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = each.value.tls_secret
      namespace = kubernetes_namespace_v1.monitoring_namespace.metadata[0].name
    }
    spec = {
      secretName = each.value.tls_secret
      dnsNames   = [each.value.host]
      issuerRef = {
        kind = "ClusterIssuer"
        name = "letsencrypt-gateway"
      }
    }
  })
}

# Attaches to this module's own ListenerSet, not to the Gateway, so a host cannot be served before
# its listener exists. All three backends speak plain HTTP on the service port.
resource "kubectl_manifest" "route" {
  for_each = local.monitoring_gateway_hosts

  # The gate must exist before the route publishes the host and outlive it on destroy, or gated
  # paths serve unauthenticated in between.
  depends_on = [kubectl_manifest.listener, kubectl_manifest.require_auth]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = local.monitoring_route_slugs[each.key]
      namespace = kubernetes_namespace_v1.monitoring_namespace.metadata[0].name
    }
    spec = {
      parentRefs = [{
        group       = "gateway.networking.k8s.io"
        kind        = "ListenerSet"
        name        = local.monitoring_route_slugs[each.key]
        sectionName = local.monitoring_route_slugs[each.key]
      }]
      hostnames = [each.value.host]
      rules = [{
        filters = [
          local.monitoring_request_header_filter,
          local.monitoring_response_header_filter,
        ]
        backendRefs = [{
          name = each.value.service
          port = each.value.port
        }]
      }]
    }
  })
}

# Requires an authenticated session for this host. action CUSTOM hands the decision to the
# ext_authz provider declared in mesh config, which is oauth2-proxy.
#
# No notPaths for the ACME challenge: these certificates are issued by DNS-01, so no HTTP challenge
# request ever arrives. An exemption here would be dead config implying otherwise.
resource "kubectl_manifest" "require_auth" {
  for_each = local.monitoring_gateway_hosts

  depends_on = [kubectl_manifest.listener]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "${local.monitoring_route_slugs[each.key]}-require-auth"
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
            hosts = [each.value.host, "${each.value.host}:*"]
          }
        }]
      }]
    }
  })
}
