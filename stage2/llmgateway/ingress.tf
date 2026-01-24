# LLM Gateway Ingress Resources
# Network exposure for UI, API, Gateway, and Admin services
# Reference: https://docs.llmgateway.io/self-host

# Ingress for LLM Gateway UI
# Main web dashboard for managing LLM Gateway
resource "kubernetes_ingress_v1" "llmgateway_ui" {
  count = var.llmgateway_enable ? 1 : 0

  metadata {
    name      = "llmgateway-ui"
    namespace = kubernetes_namespace_v1.llmgateway[0].metadata[0].name

    annotations = {
      "nginx.ingress.kubernetes.io/proxy-body-size"    = "50m"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "600"
      # OAuth2 proxy authentication - requires valid Auth0 session
      # Reference: https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/
      "nginx.ingress.kubernetes.io/auth-url"              = "https://${var.auth_oauth2_proxy_host}/oauth2/auth"
      "nginx.ingress.kubernetes.io/auth-signin"           = "https://${var.auth_oauth2_proxy_host}/oauth2/start?rd=$scheme://$host$escaped_request_uri"
      "nginx.ingress.kubernetes.io/auth-response-headers" = "X-Auth-Request-User,X-Auth-Request-Email,X-Auth-Request-Access-Token"
    }
  }

  spec {
    ingress_class_name = var.llmgateway_ingress_class_name

    dynamic "tls" {
      for_each = var.llmgateway_ingress_enable_tls ? [1] : []
      content {
        hosts       = [var.llmgateway_domain]
        secret_name = "llmgateway-tls"
      }
    }

    rule {
      host = var.llmgateway_domain

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.llmgateway[0].metadata[0].name
              port {
                number = 3002
              }
            }
          }
        }
      }
    }
  }
}

# Ingress for LLM Gateway API (internal API used by UI)
# Accessed by the frontend for user/project management
resource "kubernetes_ingress_v1" "llmgateway_api" {
  count = var.llmgateway_enable ? 1 : 0

  metadata {
    name      = "llmgateway-api"
    namespace = kubernetes_namespace_v1.llmgateway[0].metadata[0].name

    annotations = {
      "nginx.ingress.kubernetes.io/proxy-body-size"    = "50m"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "600"
      # Enable CORS for cross-subdomain requests from UI and Admin
      # Reference: https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#enable-cors
      "nginx.ingress.kubernetes.io/enable-cors"            = "true"
      "nginx.ingress.kubernetes.io/cors-allow-origin"      = "${local.llmgateway_scheme}://${var.llmgateway_domain},${local.llmgateway_scheme}://${local.llmgateway_admin_domain}"
      "nginx.ingress.kubernetes.io/cors-allow-credentials" = "true"
      # OAuth2 proxy authentication - requires valid Auth0 session
      # Reference: https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/
      "nginx.ingress.kubernetes.io/auth-url"              = "https://${var.auth_oauth2_proxy_host}/oauth2/auth"
      "nginx.ingress.kubernetes.io/auth-signin"           = "https://${var.auth_oauth2_proxy_host}/oauth2/start?rd=$scheme://$host$escaped_request_uri"
      "nginx.ingress.kubernetes.io/auth-response-headers" = "X-Auth-Request-User,X-Auth-Request-Email,X-Auth-Request-Access-Token"
    }
  }

  spec {
    ingress_class_name = var.llmgateway_ingress_class_name

    dynamic "tls" {
      for_each = var.llmgateway_ingress_enable_tls ? [1] : []
      content {
        hosts       = [local.llmgateway_api_domain]
        secret_name = "llmgateway-tls"
      }
    }

    rule {
      host = local.llmgateway_api_domain

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.llmgateway[0].metadata[0].name
              port {
                number = 4002
              }
            }
          }
        }
      }
    }
  }
}

# Ingress for LLM Gateway OpenAI-compatible endpoint
# Used by LLM clients (curl, SDKs) for chat completions
# No OAuth protection - API key authentication at application level
# Reference: https://docs.llmgateway.io/features/api-keys
resource "kubernetes_ingress_v1" "llmgateway_gateway" {
  count = var.llmgateway_enable ? 1 : 0

  metadata {
    name      = "llmgateway-gateway"
    namespace = kubernetes_namespace_v1.llmgateway[0].metadata[0].name

    annotations = {
      "nginx.ingress.kubernetes.io/proxy-body-size"    = "50m"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "600"
      # HTTP/1.1 required for SSE (Server-Sent Events) streaming responses
      # LLM Gateway uses SSE for token streaming
      "nginx.ingress.kubernetes.io/proxy-http-version" = "1.1"
      # Disable buffering for streaming responses
      "nginx.ingress.kubernetes.io/proxy-buffering" = "off"
    }
  }

  spec {
    ingress_class_name = var.llmgateway_ingress_class_name

    dynamic "tls" {
      for_each = var.llmgateway_ingress_enable_tls ? [1] : []
      content {
        hosts       = [local.llmgateway_gateway_domain]
        secret_name = "llmgateway-tls"
      }
    }

    rule {
      host = local.llmgateway_gateway_domain

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.llmgateway[0].metadata[0].name
              port {
                number = 4001
              }
            }
          }
        }
      }
    }
  }
}

# Ingress for LLM Gateway Admin panel
# Administrative interface for system-wide settings
resource "kubernetes_ingress_v1" "llmgateway_admin" {
  count = var.llmgateway_enable ? 1 : 0

  metadata {
    name      = "llmgateway-admin"
    namespace = kubernetes_namespace_v1.llmgateway[0].metadata[0].name

    annotations = {
      "nginx.ingress.kubernetes.io/proxy-body-size"    = "50m"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "600"
      # OAuth2 proxy authentication - requires valid Auth0 session
      # Reference: https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/
      "nginx.ingress.kubernetes.io/auth-url"              = "https://${var.auth_oauth2_proxy_host}/oauth2/auth"
      "nginx.ingress.kubernetes.io/auth-signin"           = "https://${var.auth_oauth2_proxy_host}/oauth2/start?rd=$scheme://$host$escaped_request_uri"
      "nginx.ingress.kubernetes.io/auth-response-headers" = "X-Auth-Request-User,X-Auth-Request-Email,X-Auth-Request-Access-Token"
    }
  }

  spec {
    ingress_class_name = var.llmgateway_ingress_class_name

    dynamic "tls" {
      for_each = var.llmgateway_ingress_enable_tls ? [1] : []
      content {
        hosts       = [local.llmgateway_admin_domain]
        secret_name = "llmgateway-tls"
      }
    }

    rule {
      host = local.llmgateway_admin_domain

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.llmgateway[0].metadata[0].name
              port {
                number = 3006
              }
            }
          }
        }
      }
    }
  }
}

# Certificate for TLS when enabled
# Lists all subdomains individually for HTTP-01 challenge validation
# Reference: https://cert-manager.io/docs/usage/certificate/
resource "kubernetes_manifest" "llmgateway_certificate" {
  count = var.llmgateway_enable && var.llmgateway_ingress_enable_tls ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"

    metadata = {
      name      = "llmgateway-tls"
      namespace = kubernetes_namespace_v1.llmgateway[0].metadata[0].name
    }

    spec = {
      secretName = "llmgateway-tls"
      issuerRef = {
        name = "letsencrypt-prod"
        kind = "ClusterIssuer"
      }
      dnsNames = [
        var.llmgateway_domain,           # UI: llm.domain
        local.llmgateway_api_domain,     # API: api.llm.domain
        local.llmgateway_gateway_domain, # Gateway: gateway.llm.domain
        local.llmgateway_admin_domain,   # Admin: admin.llm.domain
      ]
    }
  }
}
