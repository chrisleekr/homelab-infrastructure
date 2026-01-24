output "auth_namespace" {
  description = "The Kubernetes namespace where authentication services are deployed"
  value       = kubernetes_namespace_v1.auth_namespace.metadata[0].name
}

output "oauth2_proxy_cookie_secret" {
  description = "The generated cookie secret for OAuth2 Proxy session encryption"
  value       = random_password.oauth2_proxy_cookie_secret.result
  sensitive   = true
}
