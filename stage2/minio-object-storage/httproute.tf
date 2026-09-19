# Gateway API exposure for both MinIO hosts, replacing the tenant chart's Ingress.
#
# NOTE: the S3 api host has NO AuthorizationPolicy, and must not gain one. Clients authenticate
# with AWS SigV4 against MinIO itself, so an ext_authz login redirect would break every S3 caller.
# The console host beside it is gated, because it is a browser UI with no credentials of its own.
#
# The api host was the last one held back by the request size gap in the istio-gateway docs. That
# gap is about imposing caps, not preserving the lack of one: the Ingress carried proxy-body-size 0,
# meaning unlimited, and Envoy streams request bodies with no buffer filter in the chain, so
# unlimited is already what the gateway does. The gateway also leaves duplicate slashes and %2F in
# S3 object keys untouched.
locals {
  minio_console_route_slug = replace(var.minio_tenant_ingress_console_host, ".", "-")
  minio_api_route_slug     = replace(var.minio_tenant_ingress_api_host, ".", "-")

  # Header mutations every route carries. Copied per module deliberately: Gateway API has no
  # gateway-wide header policy, and mesh proxyHeaders alone does not set all of these.
  #   - server: mesh config stops Envoy overwriting it, which leaves the BACKEND value exposed.
  #     Only the route can remove the header.
  #   - x-envoy-peer-metadata and -id: mesh metadataExchangeHeaders IN_MESH did not stop these
  #     reaching a non-injected backend in 1.31. The route strips them.
  #   - x-real-ip: a client-supplied value is forwarded untouched, so every route must overwrite it
  #     or a caller can forge it. The value comes from the trusted client address, which is only
  #     correct because meshConfig sets numTrustedProxies.
  #
  # Both hosts share these. Envoy adds them after the client signed the request, so setting or
  # removing them cannot disturb an S3 SigV4 signature, which covers only the headers the client
  # listed in SignedHeaders plus Host, and no route here rewrites Host.
  minio_request_header_filter = {
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

  minio_response_header_filter = {
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

# Contributes each host's HTTPS listener to the shared Gateway. The Gateway itself never names
# these hosts, so enabling or disabling this module is the only edit a cutover needs.
resource "kubectl_manifest" "console_listener" {
  depends_on = [helm_release.minio_tenant]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "ListenerSet"
    metadata = {
      name      = local.minio_console_route_slug
      namespace = kubernetes_namespace_v1.minio_tenant.metadata[0].name
    }
    spec = {
      parentRef = {
        name      = var.istio_gateway_name
        namespace = var.istio_gateway_namespace
      }
      listeners = [{
        name     = local.minio_console_route_slug
        port     = 443
        protocol = "HTTPS"
        hostname = var.minio_tenant_ingress_console_host
        tls = {
          mode            = "Terminate"
          certificateRefs = [{ kind = "Secret", name = "minio-tenant-console-tls" }]
        }
        allowedRoutes = {
          namespaces = { from = "Same" }
        }
      }]
    }
  })
}

resource "kubectl_manifest" "api_listener" {
  depends_on = [helm_release.minio_tenant]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "ListenerSet"
    metadata = {
      name      = local.minio_api_route_slug
      namespace = kubernetes_namespace_v1.minio_tenant.metadata[0].name
    }
    spec = {
      parentRef = {
        name      = var.istio_gateway_name
        namespace = var.istio_gateway_namespace
      }
      listeners = [{
        name     = local.minio_api_route_slug
        port     = 443
        protocol = "HTTPS"
        hostname = var.minio_tenant_ingress_api_host
        tls = {
          mode            = "Terminate"
          certificateRefs = [{ kind = "Secret", name = "minio-tenant-api-tls" }]
        }
        allowedRoutes = {
          namespaces = { from = "Same" }
        }
      }]
    }
  })
}

# Same name and Secret the ingress-shim Certificates used, so the existing valid certificates keep
# being served while DNS-01 issues replacements. cert-manager does not adopt across issuers: the
# Secrets were issued by letsencrypt-prod, so these re-issue under letsencrypt-gateway.
#
# depends_on the Helm release because that upgrade removes the Ingress, and deleting it
# garbage-collects the shim-owned Certificate holding this name. The Secret survives: cert-manager
# does not own it unless --enable-certificate-owner-ref is set, which it is not here.
resource "kubectl_manifest" "console_certificate" {
  depends_on = [helm_release.minio_tenant]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "minio-tenant-console-tls"
      namespace = kubernetes_namespace_v1.minio_tenant.metadata[0].name
    }
    spec = {
      secretName = "minio-tenant-console-tls"
      dnsNames   = [var.minio_tenant_ingress_console_host]
      issuerRef = {
        kind = "ClusterIssuer"
        name = "letsencrypt-gateway"
      }
    }
  })
}

# Only the bare api host. The Ingress also carried a *.minio rule for virtual-host-style bucket
# addressing, but its TLS block never listed the wildcard and the certificate never covered it, so
# an HTTPS client could not have used it. Every caller here is path-style, see path_style true in
# the GitLab object store connection.
resource "kubectl_manifest" "api_certificate" {
  depends_on = [helm_release.minio_tenant]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "minio-tenant-api-tls"
      namespace = kubernetes_namespace_v1.minio_tenant.metadata[0].name
    }
    spec = {
      secretName = "minio-tenant-api-tls"
      dnsNames   = [var.minio_tenant_ingress_api_host]
      issuerRef = {
        kind = "ClusterIssuer"
        name = "letsencrypt-gateway"
      }
    }
  })
}

# Attaches to this module's own ListenerSet, not to the Gateway, so it cannot be served before the
# listener exists. The tenant sets requestAutoCert false, so both backends speak plain HTTP. A
# backendRef takes the port number, not the name.
resource "kubectl_manifest" "console_route" {
  # The gate must exist before the route publishes the host and outlive it on destroy, or gated
  # paths serve unauthenticated in between.
  depends_on = [kubectl_manifest.console_listener, kubectl_manifest.console_require_auth]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = local.minio_console_route_slug
      namespace = kubernetes_namespace_v1.minio_tenant.metadata[0].name
    }
    spec = {
      parentRefs = [{
        group       = "gateway.networking.k8s.io"
        kind        = "ListenerSet"
        name        = local.minio_console_route_slug
        sectionName = local.minio_console_route_slug
      }]
      hostnames = [var.minio_tenant_ingress_console_host]
      rules = [{
        filters = [
          local.minio_request_header_filter,
          local.minio_response_header_filter,
        ]
        backendRefs = [{
          name = "minio-tenant-console"
          port = 9090
        }]
      }]
    }
  })
}

# The api backend is the `minio` ClusterIP Service on port 80, which the tenant operator points at
# container port 9000. It must not be the headless Service: bucketDNS is on, so MinIO reads any
# other hostname label as a virtual-host bucket name and answers NoSuchBucket.
resource "kubectl_manifest" "api_route" {
  depends_on = [kubectl_manifest.api_listener]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = local.minio_api_route_slug
      namespace = kubernetes_namespace_v1.minio_tenant.metadata[0].name
    }
    spec = {
      parentRefs = [{
        group       = "gateway.networking.k8s.io"
        kind        = "ListenerSet"
        name        = local.minio_api_route_slug
        sectionName = local.minio_api_route_slug
      }]
      hostnames = [var.minio_tenant_ingress_api_host]
      rules = [{
        filters = [
          local.minio_request_header_filter,
          local.minio_response_header_filter,
        ]
        backendRefs = [{
          name = "minio"
          port = 80
        }]
      }]
    }
  })
}

# Requires an authenticated session for this host. action CUSTOM hands the decision to the
# ext_authz provider declared in mesh config, which is oauth2-proxy. Console only, see the note at
# the top of this file for why the api host gets none.
#
# No notPaths for the ACME challenge: this host's certificate is issued by DNS-01, so no HTTP
# challenge request ever arrives. An exemption here would be dead config implying otherwise.
resource "kubectl_manifest" "console_require_auth" {
  depends_on = [kubectl_manifest.console_listener]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "${local.minio_console_route_slug}-require-auth"
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
            hosts = [var.minio_tenant_ingress_console_host, "${var.minio_tenant_ingress_console_host}:*"]
          }
        }]
      }]
    }
  })
}
