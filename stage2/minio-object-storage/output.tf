output "minio_tenant_root_password" {
  description = "The root password for MinIO tenant console access"
  value       = random_password.minio_tenant_root_password.result
  sensitive   = true
}

output "minio_tenant_user_secret_key" {
  description = "The secret access key for MinIO tenant user S3 API operations"
  value       = random_password.minio_tenant_user_secret_key.result
  sensitive   = true
}
