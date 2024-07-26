output "minio_tenant_root_password" {
  value     = random_password.minio_tenant_root_password.result
  sensitive = true
}

output "minio_tenant_user_secret_key" {
  value     = random_password.minio_tenant_user_secret_key.result
  sensitive = true
}
