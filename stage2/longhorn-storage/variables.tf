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

variable "longhorn_ingress_enable_tls" {
  description = "Enable TLS for the services"
  type        = bool
  default     = true
}

variable "auth_oauth2_proxy_host" {
  description = "The host for the oauth2 proxy"
  type        = string
  default     = "auth.chrislee.local"
}
