output "minio_tenant_root_password" {
  value     = module.minio_object_storage.minio_tenant_root_password
  sensitive = true

}

output "minio_tenant_user_secret_key" {
  value     = module.minio_object_storage.minio_tenant_user_secret_key
  sensitive = true
}

output "gitlab_initial_root_passwrd" {
  value     = module.gitlab_platform.gitlab_initial_root_password
  sensitive = true
}

output "gitlab_runner_registration_token" {
  value     = module.gitlab_platform.gitlab_runner_registration_token
  sensitive = true
}

output "gitlab_shell_host_keys" {
  value     = module.gitlab_platform.gitlab_shell_host_keys
  sensitive = true
}

output "grafana_admin_password" {
  value     = module.prometheus_stack.grafana_admin_password
  sensitive = true
}
