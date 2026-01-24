# Generate cookie secret
resource "random_password" "oauth2_proxy_cookie_secret" {
  length  = 16
  special = false
}

resource "kubernetes_secret_v1" "oauth2_proxy_cookie_secret" {
  metadata {
    name      = "oauth2-proxy-cookie-secret"
    namespace = kubernetes_namespace_v1.auth_namespace.metadata[0].name
  }

  data = {
    "client-id"     = var.auth_auth0_client_id
    "client-secret" = var.auth_auth0_client_secret
    "cookie-secret" = random_password.oauth2_proxy_cookie_secret.result
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}


resource "helm_release" "oauth2_proxy" {
  depends_on = [kubernetes_namespace_v1.auth_namespace]

  name       = "oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = "9.0.0"
  namespace  = kubernetes_namespace_v1.auth_namespace.metadata[0].name
  timeout    = 300
  wait       = true

  values = [
    templatefile(
      "${path.module}/templates/oauth2-proxy.tftpl",
      {
        auth0_domain                   = var.auth_auth0_domain
        oauth2_proxy_host              = var.auth_oauth2_proxy_host
        oauth2_proxy_cookie_domains    = var.auth_oauth2_proxy_cookie_domains
        oauth2_proxy_whitelist_domains = var.auth_oauth2_proxy_whitelist_domains

        ingress_class_name   = var.auth_ingress_class_name
        ingress_enable_tls   = var.auth_ingress_enable_tls
        prometheus_namespace = var.prometheus_namespace

        host_alias_ip        = var.auth_host_alias_ip
        host_alias_hostnames = var.auth_host_alias_hostnames
      }
    ),
  ]
}
