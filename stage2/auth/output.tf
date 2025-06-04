output "auth_namespace" {
  value = kubernetes_namespace.auth_namespace.metadata[0].name
}

output "oauth2_proxy_cookie_secret" {
  value     = random_password.oauth2_proxy_cookie_secret.result
  sensitive = true
}
