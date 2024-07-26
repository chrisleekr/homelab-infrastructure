variable "nginx_frontend_basic_auth_base64" {
  description = "Base64 encoded username:password for basic auth - htpasswd -nb user password | openssl base64"
  type        = string
  sensitive   = true
}

variable "longhorn_default_settings_default_data_path" {
  description = "Default path for storing data on a host. The default value is /var/lib/longhorn/."
  type        = string
  default     = "/var/lib/longhorn"
}

variable "longhorn_ingress_class_name" {
  description = "Ingress class name for Longhorn."
  type        = string
}

variable "longhorn_ingress_host" {
  description = "Hostname of the Layer 7 load balancer."
  type        = string
}
