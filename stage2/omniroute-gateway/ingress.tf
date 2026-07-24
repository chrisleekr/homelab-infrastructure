# Two Ingresses on the SAME host. nginx merges rules per host and matches the longest path first,
# so var.omniroute_public_paths (default /api/v1) hit the open API Ingress while "/" and everything
# else fall through to the oauth2-proxy-gated UI Ingress. /api/v1 is longer than /, so API clients
# always land on the open Ingress.
#
# The match is a longest LITERAL STRING prefix, not the element-wise prefix the Ingress spec
# describes: ingress-nginx renders pathType Prefix as a plain nginx prefix location. "/api/v1"
# therefore also opens "/api/v1beta" and "/api/v1-anything", not only true "/api/v1/" children. No
# such sibling route exists in the pinned appVersion, but a future upstream route named that way
# would land on the OPEN Ingress. Recheck this list on every image bump.
# Ref: https://kubernetes.github.io/ingress-nginx/user-guide/ingress-path-matching/
#
# This is the INVERSE of the litellm split: there "/" is the open API and listed paths are gated;
# here "/" is the gated dashboard and listed paths are the open API.
#
# Both Ingresses keep the same host and the same TLS secret. cert-manager only adds SANs for the
# Ingress it is annotated on, and only ONE of the two carries the cluster-issuer annotation (the
# UI). Two annotated Ingresses sharing one TLS secret would create competing Certificates.

# Open API surface. No oauth2-proxy: OmniRoute enforces REQUIRE_API_KEY on /api/v1 itself (forced in
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
        # Specific /api/v1 admin subpaths pulled back behind oauth2 as defense in depth over
        # REQUIRE_API_KEY. These sit under the open /api/v1 prefix but carry management-grade
        # functions (proxy config, agent credentials, accounts, registered keys), so the open
        # ingress alone would rest their protection entirely on OmniRoute's in-app API-key authz.
        # nginx matches the longest prefix, and these are longer than the open ingress's /api/v1,
        # so they route here and require an oauth2 session. The dashboard's own browser calls to
        # them still pass: the browser already holds the oauth2 cookie.
        dynamic "path" {
          for_each = var.omniroute_gated_api_paths

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
