output "minio_tenant_root_password" {
  value     = module.minio_object_storage.minio_tenant_root_password
  sensitive = true

}

output "minio_tenant_user_secret_key" {
  value     = module.minio_object_storage.minio_tenant_user_secret_key
  sensitive = true
}

output "gitlab_initial_root_password" {
  value     = length(module.gitlab_platform) > 0 ? module.gitlab_platform[0].gitlab_initial_root_password : null
  sensitive = true
}

output "gitlab_shell_host_keys" {
  value     = length(module.gitlab_platform) > 0 ? module.gitlab_platform[0].gitlab_shell_host_keys : null
  sensitive = true
}

output "grafana_admin_password" {
  value     = module.monitoring.grafana_admin_password
  sensitive = true
}

output "elasticsearch_password" {
  value     = try(module.logging[0].elasticsearch_password, "")
  sensitive = true
}

output "argocd_initial_admin_password" {
  value     = module.argocd.argocd_initial_admin_password
  sensitive = true
}
