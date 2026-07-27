variable "nginx_frontend_basic_auth_base64" {
  description = "Base64 encoded username:password for basic auth - htpasswd -nb user password | openssl base64"
  type        = string
  sensitive   = true
}

variable "kubecost_token" {
  description = "Kubecost token - retrieved from https://www.kubecost.com/install.html#show-instructions"
  type        = string
  sensitive   = true
}

# Stamped onto every cost record Kubecost writes, so changing it on a live install orphans the
# existing ETL history under the old identity.
variable "kubecost_cluster_id" {
  description = "Unique identifier for this cluster in Kubecost. Must be distinct per cluster reporting into the same Kubecost."
  type        = string
  default     = "homelab"

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
