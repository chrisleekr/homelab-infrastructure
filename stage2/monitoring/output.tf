output "monitoring_namespace" {
  value = kubernetes_namespace.monitoring_namespace.metadata[0].name
}

output "grafana_admin_password" {
  value     = random_password.grafana_admin_password.result
  sensitive = true
}
