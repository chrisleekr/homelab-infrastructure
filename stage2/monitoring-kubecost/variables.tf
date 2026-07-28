variable "nginx_frontend_basic_auth_base64" {
  description = "Base64 encoded username:password for basic auth - htpasswd -nb user password | openssl base64"
  type        = string
  sensitive   = true
}

# Stamped inside every cost record Kubecost writes, not just its path in the federated store, so
# changing it on a live install orphans the existing ETL history under the old identity and no
# amount of re-pathing recovers it. Kept at kubecost's stock default because the existing ETL is
# filed under that name.
variable "kubecost_cluster_id" {
  description = "Unique identifier for this cluster in Kubecost. Must be distinct per cluster reporting into the same Kubecost."
  type        = string
  default     = "cluster-one"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9_-]*[a-z0-9])?$", var.kubecost_cluster_id))
    error_message = "kubecost_cluster_id must be lowercase alphanumeric, optionally separated by \"-\" or \"_\"."
  }
}

variable "kubecost_ingress_enable_tls" {
  description = "Enable TLS for the kubecost ingress"
  type        = bool
  default     = true
}


variable "kubecost_ingress_class_name" {
  description = "Ingress class name for the kubecost"
  type        = string
  default     = "nginx"
}

variable "kubecost_ingress_host" {
  description = "The host for the kubecost ingress"
  type        = string
  default     = "cost.chrislee.local"
}

variable "auth_oauth2_proxy_host" {
  description = "The host for the oauth2 proxy"
  type        = string
  default     = "auth.chrislee.local"
}

variable "minio_endpoint" {
  description = "In-cluster S3 endpoint for MinIO, e.g. minio.minio-tenant.svc.cluster.local:80."
  type        = string
}

variable "minio_access_key" {
  description = "MinIO access key for the tenant user"
  type        = string
}

variable "minio_secret_key" {
  description = "MinIO secret key for the tenant user"
  type        = string
  sensitive   = true
}

variable "minio_bucket_name" {
  description = "Name of the MinIO bucket for Kubecost federated storage"
  type        = string
  default     = "kubecost-federated-store"
}
