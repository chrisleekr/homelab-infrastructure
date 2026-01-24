output "argocd_initial_admin_password" {
  description = "The initial admin password for ArgoCD web UI access"
  value       = data.kubernetes_secret_v1.argocd_initial_admin_secret.data["password"]
  sensitive   = true
}
