output "minio_tenant_root_password" {
  value     = module.minio_object_storage.minio_tenant_root_password
  sensitive = true

}

output "minio_tenant_user_secret_key" {
  value     = module.minio_object_storage.minio_tenant_user_secret_key
  sensitive = true
}

output "gitlab_initial_root_passwrd" {
  value     = length(module.gitlab_platform) > 0 ? module.gitlab_platform[0].gitlab_initial_root_password : null
  sensitive = true
}

output "gitlab_runner_registration_token" {
  value     = length(module.gitlab_platform) > 0 ? module.gitlab_platform[0].gitlab_runner_registration_token : null
  sensitive = true
}

output "gitlab_shell_host_keys" {
  value     = length(module.gitlab_platform) > 0 ? module.gitlab_platform[0].gitlab_shell_host_keys : null
  sensitive = true
}

output "grafana_admin_password" {
  value     = module.prometheus_stack.grafana_admin_password
  sensitive = true
}

output "elasticsearch_password" {
  value     = module.logging.elasticsearch_password
  sensitive = true
}
