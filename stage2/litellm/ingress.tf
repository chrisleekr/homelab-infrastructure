# Two Ingresses on the SAME host. nginx merges rules per host and matches the longest path first,
# so var.litellm_ui_paths hit the oauth2-proxy-protected Ingress while everything else falls
# through to the API Ingress.
#
# Both must keep the same host: cert-manager only adds SANs for the Ingress it is annotated on, and
# only ONE of the two carries the cluster-issuer annotation. Two annotated Ingresses sharing one
# TLS secret would create competing Certificates for that secret.

# API surface. No oauth2-proxy: LiteLLM enforces the master key itself on /v1, and an HTTP redirect
# to an SSO login page would break SDK clients.
resource "kubernetes_ingress_v1" "api" {
  count = var.litellm_enable ? 1 : 0

  depends_on = [helm_release.litellm]

  metadata {
    name      = "litellm-api"
    namespace = local.litellm_namespace

    annotations = merge(
      local.litellm_ingress_base_annotations,
      {
        # HTTP/1.1 with response buffering off is what makes SSE token streaming actually stream.
        "nginx.ingress.kubernetes.io/proxy-http-version" = "1.1"
        "nginx.ingress.kubernetes.io/proxy-buffering"    = "off"
      },
      # This is the only Ingress of the pair that cert-manager may act on.
      var.litellm_ingress_enable_tls ? {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      } : {}
    )
  }

  spec {
    ingress_class_name = var.litellm_ingress_class_name

    dynamic "tls" {
      for_each = var.litellm_ingress_enable_tls ? [1] : []
      content {
        hosts       = [var.litellm_domain]
        secret_name = local.litellm_tls_secret_name
      }
    }

    rule {
      host = var.litellm_domain

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = local.litellm_service_name
              port {
                number = local.litellm_service_port
              }
            }
          }
        }
      }
    }
  }
}

# Admin console. LiteLLM serves /ui/ with no credentials of its own, so without this oauth2-proxy
# gate the console HTML would be public. LiteLLM still enforces the master key on the management
# API behind it.
#
# depends_on the API Ingress purely for deterministic creation order: both declare the same
# tls.secret_name, and the annotated one should exist first.
resource "kubernetes_ingress_v1" "ui" {
  count = var.litellm_enable ? 1 : 0

  depends_on = [kubernetes_ingress_v1.api]

  metadata {
    name      = "litellm-ui"
    namespace = local.litellm_namespace

    annotations = merge(
      local.litellm_ingress_base_annotations,
      {
        # Reference: https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/
        "nginx.ingress.kubernetes.io/auth-url"              = "https://${var.auth_oauth2_proxy_host}/oauth2/auth"
        "nginx.ingress.kubernetes.io/auth-signin"           = "https://${var.auth_oauth2_proxy_host}/oauth2/start?rd=$scheme://$host$escaped_request_uri"
        "nginx.ingress.kubernetes.io/auth-response-headers" = "X-Auth-Request-User,X-Auth-Request-Email,X-Auth-Request-Access-Token"
      }
    )
  }

  spec {
    ingress_class_name = var.litellm_ingress_class_name

    dynamic "tls" {
      for_each = var.litellm_ingress_enable_tls ? [1] : []
      content {
        hosts       = [var.litellm_domain]
        secret_name = local.litellm_tls_secret_name
      }
    }

    rule {
      host = var.litellm_domain

      http {
        dynamic "path" {
          for_each = var.litellm_ui_paths

          content {
            path      = path.value
            path_type = "Prefix"

            backend {
              service {
                name = local.litellm_service_name
                port {
                  number = local.litellm_service_port
                }
              }
            }
          }
        }
      }
    }
  }
}
