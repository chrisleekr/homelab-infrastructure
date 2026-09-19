# Gateway API exposure for the GitLab web host and the container registry, replacing the two
# Ingresses the chart used to render for them.
#
# NOTE: neither host has an AuthorizationPolicy, and neither may gain one. GitLab runs its own
# session login and the registry authenticates with JWT bearer tokens issued by GitLab, so an
# ext_authz login redirect would break git over HTTPS, the API, CI, and every docker pull.
#
# Request sizes need nothing here. Both Ingresses set proxy-body-size 0, meaning no limit, and Envoy
# streams request bodies with no buffer filter in the gateway's chain, which is what makes large
# registry layer pushes and git pushes work. The route timeout and stream idle timeout are both 0s
# against the 600s and 900s read timeouts the Ingresses carried.
locals {
  gitlab_web_host      = "gitlab.${var.gitlab_global_hosts_domain}"
  gitlab_registry_host = "registry.${var.gitlab_global_hosts_domain}"

  gitlab_web_route_slug      = replace(local.gitlab_web_host, ".", "-")
  gitlab_registry_route_slug = replace(local.gitlab_registry_host, ".", "-")

  # Header mutations every route carries. Copied per module deliberately: Gateway API has no
  # gateway-wide header policy, and mesh proxyHeaders alone does not set all of these.
  #   - server: mesh config stops Envoy overwriting it, which leaves the BACKEND value exposed.
  #     Only the route can remove the header.
  #   - x-envoy-peer-metadata and -id: mesh metadataExchangeHeaders IN_MESH did not stop these
  #     reaching a non-injected backend in 1.31. The route strips them.
  #   - x-real-ip: a client-supplied value is forwarded untouched, so every route must overwrite it
  #     or a caller can forge it. The value comes from the trusted client address, which is only
  #     correct because meshConfig sets numTrustedProxies.
  gitlab_request_header_filter = {
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

  gitlab_response_header_filter = {
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
#
# These two must NOT depend on helm_release.gitlab. The chart waits for the runner to be Ready, the
# runner registers against the GitLab host, and once CoreDNS points that host at the gateway the
# registration needs this listener to exist. Ordering the listener after the upgrade deadlocks both:
# the upgrade sat 13 minutes and would have failed at its 45 minute timeout. Creating the listener
# first is safe, because the Ingress and the listener can serve the same host at once.
# The Certificates below are different and do keep the dependency.
resource "kubectl_manifest" "web_listener" {
  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "ListenerSet"
    metadata = {
      name      = local.gitlab_web_route_slug
      namespace = kubernetes_namespace_v1.gitlab.metadata[0].name
    }
    spec = {
      parentRef = {
        name      = var.istio_gateway_name
        namespace = var.istio_gateway_namespace
      }
      listeners = [{
        name     = local.gitlab_web_route_slug
        port     = 443
        protocol = "HTTPS"
        hostname = local.gitlab_web_host
        tls = {
          mode            = "Terminate"
          certificateRefs = [{ kind = "Secret", name = "gitlab-webservice-tls" }]
        }
        allowedRoutes = {
          namespaces = { from = "Same" }
        }
      }]
    }
  })
}

resource "kubectl_manifest" "registry_listener" {
  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "ListenerSet"
    metadata = {
      name      = local.gitlab_registry_route_slug
      namespace = kubernetes_namespace_v1.gitlab.metadata[0].name
    }
    spec = {
      parentRef = {
        name      = var.istio_gateway_name
        namespace = var.istio_gateway_namespace
      }
      listeners = [{
        name     = local.gitlab_registry_route_slug
        port     = 443
        protocol = "HTTPS"
        hostname = local.gitlab_registry_host
        tls = {
          mode            = "Terminate"
          certificateRefs = [{ kind = "Secret", name = "registry-tls" }]
        }
        allowedRoutes = {
          namespaces = { from = "Same" }
        }
      }]
    }
  })
}

# Same names and Secrets the ingress-shim Certificates used, so the existing valid certificates keep
# being served while DNS-01 issues replacements. cert-manager does not adopt across issuers: both
# Secrets were issued by letsencrypt-prod, so these re-issue under letsencrypt-gateway with the old
# certificate still in the Secret throughout, which is why there is no TLS gap.
#
# depends_on the Helm release because that upgrade removes the Ingresses, and deleting one
# garbage-collects the shim-owned Certificate holding its name.
resource "kubectl_manifest" "web_certificate" {
  depends_on = [helm_release.gitlab]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "gitlab-webservice-tls"
      namespace = kubernetes_namespace_v1.gitlab.metadata[0].name
    }
    spec = {
      secretName = "gitlab-webservice-tls"
      dnsNames   = [local.gitlab_web_host]
      issuerRef = {
        kind = "ClusterIssuer"
        name = "letsencrypt-gateway"
      }
    }
  })
}

resource "kubectl_manifest" "registry_certificate" {
  depends_on = [helm_release.gitlab]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "registry-tls"
      namespace = kubernetes_namespace_v1.gitlab.metadata[0].name
    }
    spec = {
      secretName = "registry-tls"
      dnsNames   = [local.gitlab_registry_host]
      issuerRef = {
        kind = "ClusterIssuer"
        name = "letsencrypt-gateway"
      }
    }
  })
}

# Attaches to this module's own ListenerSet, not to the Gateway, so it cannot be served before the
# listener exists. Port 8181 is workhorse, which is what the Ingress used: it fronts the Rails
# webservice on 8080 and is the only port that handles git over HTTPS and large uploads correctly.
# A backendRef takes the port number, not the name.
resource "kubectl_manifest" "web_route" {
  depends_on = [kubectl_manifest.web_listener]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = local.gitlab_web_route_slug
      namespace = kubernetes_namespace_v1.gitlab.metadata[0].name
    }
    spec = {
      parentRefs = [{
        group       = "gateway.networking.k8s.io"
        kind        = "ListenerSet"
        name        = local.gitlab_web_route_slug
        sectionName = local.gitlab_web_route_slug
      }]
      hostnames = [local.gitlab_web_host]
      rules = [{
        filters = [
          local.gitlab_request_header_filter,
          local.gitlab_response_header_filter,
        ]
        backendRefs = [{
          name = "gitlab-webservice-default"
          port = 8181
        }]
      }]
    }
  })
}

resource "kubectl_manifest" "registry_route" {
  depends_on = [kubectl_manifest.registry_listener]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = local.gitlab_registry_route_slug
      namespace = kubernetes_namespace_v1.gitlab.metadata[0].name
    }
    spec = {
      parentRefs = [{
        group       = "gateway.networking.k8s.io"
        kind        = "ListenerSet"
        name        = local.gitlab_registry_route_slug
        sectionName = local.gitlab_registry_route_slug
      }]
      hostnames = [local.gitlab_registry_host]
      rules = [{
        filters = [
          local.gitlab_request_header_filter,
          local.gitlab_response_header_filter,
        ]
        backendRefs = [{
          name = "gitlab-registry"
          port = 5000
        }]
      }]
    }
  })
}
