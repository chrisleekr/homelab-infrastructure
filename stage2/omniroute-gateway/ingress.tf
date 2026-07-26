# Two Ingresses on the SAME host. This is the documented way to mix authenticated and open paths
# on one host: auth-url/auth-signin are per-Ingress-object annotations, so there is no per-path auth
# toggle within a single Ingress.
# Ref: https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/ ("Key Detail")
#
# nginx merges rules per host and matches the longest path first, so var.omniroute_public_paths hit
# the open API Ingress while "/" and everything else fall through to the oauth2-proxy-gated UI
# Ingress. The admin paths in locals.tf are longer still, so they route back to the gated Ingress.
#
# Matching is ELEMENT-WISE: "/foo/bar matches /foo/bar/baz, but does not match /foo/barbaz". A
# sibling like /v1beta therefore does NOT match the open /v1 and stays gated; opening it would mean
# adding it to var.omniroute_public_paths explicitly.
# Ref: https://kubernetes.io/docs/reference/kubernetes-api/service-resources/ingress-v1/ (pathType)
#
# That holds only while no Ingress on this host sets use-regex or rewrite-target. Either annotation
# forces regex locations onto ALL paths for the host, switching to longest-literal matching, and
# /v1 would then swallow /v1beta.
# Ref: https://kubernetes.github.io/ingress-nginx/user-guide/ingress-path-matching/
#
# This is the INVERSE of the litellm split: there "/" is the open API and listed paths are gated;
# here "/" is the gated dashboard and listed paths are the open API.
#
# Both Ingresses keep the same host and the same TLS secret. cert-manager only adds SANs for the
# Ingress it is annotated on, and only ONE of the two carries the cluster-issuer annotation (the
# UI). Two annotated Ingresses sharing one TLS secret would create competing Certificates.

# Open API surface. No oauth2-proxy: OmniRoute enforces REQUIRE_API_KEY on the API itself (forced in
# the values template), and an HTTP redirect to an SSO login page would break SDK clients streaming
# SSE.
resource "kubernetes_ingress_v1" "api" {
  count = var.omniroute_enable ? 1 : 0

  depends_on = [helm_release.omniroute]

  metadata {
    name      = "omniroute-api"
    namespace = local.omniroute_namespace

    annotations = merge(
      local.omniroute_ingress_base_annotations,
      {
        # HTTP/1.1 with response buffering off is what makes SSE token streaming actually stream.
        "nginx.ingress.kubernetes.io/proxy-http-version" = "1.1"
        "nginx.ingress.kubernetes.io/proxy-buffering"    = "off"
      }
    )
  }

  spec {
    ingress_class_name = var.omniroute_ingress_class_name

    dynamic "tls" {
      for_each = var.omniroute_ingress_enable_tls ? [1] : []
      content {
        hosts       = [var.omniroute_domain]
        secret_name = local.omniroute_tls_secret_name
      }
    }

    rule {
      host = var.omniroute_domain

      http {
        dynamic "path" {
          for_each = var.omniroute_public_paths

          content {
            path      = path.value
            path_type = "Prefix"

            backend {
              service {
                name = local.omniroute_service_name
                port {
                  number = local.omniroute_service_port
                }
              }
            }
          }
        }
      }
    }
  }
}

# Dashboard plus every non-public path. OmniRoute serves the dashboard at "/" with no gate of its
# own, so without this oauth2-proxy gate the console HTML would be public. The catch-all "/" also
# captures any /api path not listed in var.omniroute_public_paths, keeping provider callbacks and
# management routes behind auth.
#
# This is the only Ingress of the pair cert-manager may act on. depends_on the API Ingress purely
# for deterministic creation order: both declare the same tls.secret_name.
resource "kubernetes_ingress_v1" "ui" {
  count = var.omniroute_enable ? 1 : 0

  depends_on = [kubernetes_ingress_v1.api]

  # Empty host renders auth-url as https:///oauth2/auth. ingress-nginx rejects that location and
  # returns 503, so the dashboard fails closed rather than open, but the gate is broken either way.
  # Caught at plan time here rather than in a variable validation, which cannot see omniroute_enable.
  lifecycle {
    precondition {
      condition     = trimspace(var.auth_oauth2_proxy_host) != ""
      error_message = "auth_oauth2_proxy_host must be set when omniroute_enable is true: it is interpolated into the oauth2-proxy annotations guarding the dashboard."
    }
  }

  metadata {
    name      = "omniroute-ui"
    namespace = local.omniroute_namespace

    annotations = merge(
      local.omniroute_ingress_base_annotations,
      {
        # Reference: https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/
        "nginx.ingress.kubernetes.io/auth-url"              = "https://${var.auth_oauth2_proxy_host}/oauth2/auth"
        "nginx.ingress.kubernetes.io/auth-signin"           = "https://${var.auth_oauth2_proxy_host}/oauth2/start?rd=$scheme://$host$escaped_request_uri"
        "nginx.ingress.kubernetes.io/auth-response-headers" = "X-Auth-Request-User,X-Auth-Request-Email,X-Auth-Request-Access-Token"
      },
      # This is the only Ingress of the pair that cert-manager may act on.
      var.omniroute_ingress_enable_tls ? {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      } : {}
    )
  }

  spec {
    ingress_class_name = var.omniroute_ingress_class_name

    dynamic "tls" {
      for_each = var.omniroute_ingress_enable_tls ? [1] : []
      content {
        hosts       = [var.omniroute_domain]
        secret_name = local.omniroute_tls_secret_name
      }
    }

    rule {
      host = var.omniroute_domain

      http {
        # Management-grade routes pulled back behind oauth2 as defense in depth over REQUIRE_API_KEY,
        # which would otherwise be their only protection. Longer than the open prefixes, so they
        # route here. Dashboard browser calls still pass, carrying the oauth2 cookie.
        # Derived in locals.tf; see the alias-prefix comment there for why a subset gates nothing.
        dynamic "path" {
          for_each = local.omniroute_gated_admin_paths

          content {
            path      = path.value
            path_type = "Prefix"

            backend {
              service {
                name = local.omniroute_service_name
                port {
                  number = local.omniroute_service_port
                }
              }
            }
          }
        }

        # Catch-all: the dashboard, its assets, and every /api path not explicitly opened.
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = local.omniroute_service_name
              port {
                number = local.omniroute_service_port
              }
            }
          }
        }
      }
    }
  }
}
