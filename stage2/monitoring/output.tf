output "monitoring_namespace" {
  description = "The Kubernetes namespace where monitoring stack is deployed"
  value       = kubernetes_namespace_v1.monitoring_namespace.metadata[0].name
}

output "grafana_admin_password" {
  description = "The admin password for Grafana dashboard access"
  value       = random_password.grafana_admin_password.result
  sensitive   = true
}
