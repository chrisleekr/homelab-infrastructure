# Gateway API exposure for oauth2-proxy, replacing the chart's Ingress.
#
# NOTE: this host has NO AuthorizationPolicy and must never gain one. oauth2-proxy IS the ext_authz
# provider every gated host calls, so gating it would make the authenticator depend on itself and
# deadlock every login.
#
# Cutting this host over does not affect the gate check for the other hosts. The mesh calls the
# provider at istio_gateway_ext_authz_service, which is the oauth2-proxy Service in cluster DNS, not
# this public hostname. What does depend on the hostname is browser-side: the login redirect and the
# Auth0 callback URL, which is why logins for every gated host break until the Cloudflare route is
# repointed, while existing session cookies keep working throughout.
locals {
  auth_route_slug = replace(var.auth_oauth2_proxy_host, ".", "-")

  # Header mutations every route carries. Copied per module deliberately: Gateway API has no
  # gateway-wide header policy, and mesh proxyHeaders alone does not set all of these.
  #   - server: mesh config stops Envoy overwriting it, which leaves the BACKEND value exposed.
  #     Only the route can remove the header.
  #   - x-envoy-peer-metadata and -id: mesh metadataExchangeHeaders IN_MESH did not stop these
  #     reaching a non-injected backend in 1.31. The route strips them.
  #   - x-real-ip: a client-supplied value is forwarded untouched, so every route must overwrite it
  #     or a caller can forge it. The value comes from the trusted client address, which is only
  #     correct because meshConfig sets numTrustedProxies.
  auth_request_header_filter = {
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

  auth_response_header_filter = {
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
#
# Deliberately NOT dependent on helm_release.oauth2_proxy. Ordering a listener after the chart that
# serves it deadlocked the GitLab cutover, because the release waited on a workload that needed the
# listener. The Ingress and the listener can serve the same host at once, so creating this first is
# always safe. The Certificate below is the one resource that does need the release ordering.
resource "kubectl_manifest" "listener" {
  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "ListenerSet"
    metadata = {
      name      = local.auth_route_slug
      namespace = kubernetes_namespace_v1.auth_namespace.metadata[0].name
    }
    spec = {
      parentRef = {
        name      = var.istio_gateway_name
        namespace = var.istio_gateway_namespace
      }
      listeners = [{
        name     = local.auth_route_slug
        port     = 443
        protocol = "HTTPS"
        hostname = var.auth_oauth2_proxy_host
        tls = {
          mode            = "Terminate"
          certificateRefs = [{ kind = "Secret", name = "oauth2-proxy-tls" }]
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
# depends_on the Helm release because that upgrade removes the Ingress, and deleting it
# garbage-collects the shim-owned Certificate holding this name. The Secret survives: cert-manager
# does not own it unless --enable-certificate-owner-ref is set, which it is not here.
resource "kubectl_manifest" "certificate" {
  depends_on = [helm_release.oauth2_proxy]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "oauth2-proxy-tls"
      namespace = kubernetes_namespace_v1.auth_namespace.metadata[0].name
    }
    spec = {
      secretName = "oauth2-proxy-tls"
      dnsNames   = [var.auth_oauth2_proxy_host]
      issuerRef = {
        kind = "ClusterIssuer"
        name = "letsencrypt-gateway"
      }
    }
  })
}

# Attaches to this module's own ListenerSet, not to the Gateway, so it cannot be served before the
# listener exists. oauth2-proxy speaks plain HTTP on the Service port named http, so the gateway
# terminates TLS and forwards cleartext. A backendRef takes the port number, not the name.
resource "kubectl_manifest" "route" {
  depends_on = [kubectl_manifest.listener]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = local.auth_route_slug
      namespace = kubernetes_namespace_v1.auth_namespace.metadata[0].name
    }
    spec = {
      parentRefs = [{
        group       = "gateway.networking.k8s.io"
        kind        = "ListenerSet"
        name        = local.auth_route_slug
        sectionName = local.auth_route_slug
      }]
      hostnames = [var.auth_oauth2_proxy_host]
      rules = [{
        filters = [
          local.auth_request_header_filter,
          local.auth_response_header_filter,
        ]
        backendRefs = [{
          name = "oauth2-proxy"
          port = 80
        }]
      }]
    }
  })
}
