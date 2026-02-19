output "sealed_secrets_namespace" {
  description = "Namespace where the sealed-secrets controller is deployed"
  value       = kubernetes_namespace_v1.sealed_secrets_namespace.metadata[0].name
}
