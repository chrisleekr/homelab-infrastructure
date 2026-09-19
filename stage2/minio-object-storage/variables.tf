variable "minio_tenant_root_user" {
  description = "The minio tenant's root user. Default to minio"
  type        = string
  default     = "minio"
}

variable "minio_tenant_pools_servers" {
  description = "The number of MinIO Tenant Pods / Servers in this pool. For standalone mode, supply 1. For distributed mode, supply 4 or more. Note that the operator does not support upgrading from standalone to distributed mode."
  type        = number
  default     = 1
}

variable "minio_tenant_pools_size" {
  description = "The capacity per volume requested per MinIO Tenant Pod."
  type        = string
  default     = "10Gi"
}

variable "minio_tenant_pools_storage_class_name" {
  description = "The storage class name to use for the MinIO Tenant Pods."
  type        = string
  default     = "longhorn"
}

variable "minio_tenant_default_buckets" {
  description = "The default bucket names for the tenant"
  type        = list(string)
}

variable "minio_tenant_user_access_key" {
  description = "The minio console access key. Default to minio"
  type        = string
  default     = "minio-user"
}

variable "minio_tenant_ingress_api_host" {
  description = "The hostname of the minio tenant api"
  type        = string
  default     = "minio.chrislee.local"
}

variable "minio_tenant_ingress_console_host" {
  description = "The hostname of the minio tenant console"
  type        = string
  default     = "minio-console.chrislee.local"
}

variable "istio_gateway_name" {
  description = "Name of the shared Istio Gateway this module contributes its console listener to."
  type        = string
  default     = "public"
}

variable "istio_gateway_namespace" {
  description = "Namespace of the shared Istio Gateway. The AuthorizationPolicy is created here, because Istio requires a policy to sit beside the resource its targetRefs names."
  type        = string
  default     = "istio-ingress"
}
