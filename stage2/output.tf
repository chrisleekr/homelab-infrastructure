output "minio_tenant_root_password" {
  description = "The root password for MinIO tenant admin access"
  value       = module.minio_object_storage.minio_tenant_root_password
  sensitive   = true
}

output "minio_tenant_user_secret_key" {
  description = "The secret key for MinIO tenant user API access"
  value       = module.minio_object_storage.minio_tenant_user_secret_key
  sensitive   = true
}

output "gitlab_initial_root_password" {
  description = "The initial root password for GitLab admin access (null if GitLab is disabled)"
  value       = length(module.gitlab_platform) > 0 ? module.gitlab_platform[0].gitlab_initial_root_password : null
  sensitive   = true
}

output "gitlab_shell_host_keys" {
  description = "The SSH host keys for GitLab Shell (null if GitLab is disabled)"
  value       = length(module.gitlab_platform) > 0 ? module.gitlab_platform[0].gitlab_shell_host_keys : null
  sensitive   = true
}

output "grafana_admin_password" {
  description = "The admin password for Grafana dashboard access"
  value       = module.monitoring.grafana_admin_password
  sensitive   = true
}

output "elasticsearch_password" {
  description = "The elastic user password for Elasticsearch access (empty if logging is disabled)"
  value       = try(module.logging[0].elasticsearch_password, "")
  sensitive   = true
}

output "argocd_initial_admin_password" {
  description = "The initial admin password for ArgoCD web UI access"
  value       = module.argocd.argocd_initial_admin_password
  sensitive   = true
}
