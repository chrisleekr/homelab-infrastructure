variable "prometheus_namespace" {
  description = "The namespace for the prometheus"
  type        = string
  default     = "monitoring"
}

variable "auth_ingress_class_name" {
  description = "Ingress class name for the oauth2 proxy"
  type        = string
  default     = "nginx"
}

variable "auth_ingress_enable_tls" {
  description = "Enable TLS for the oauth2 proxy"
  type        = bool
  default     = true
}

variable "auth_oauth2_proxy_host" {
  description = "The host for the oauth2 proxy"
  type        = string
  default     = "auth.chrislee.local"
}

variable "auth_oauth2_proxy_cookie_domains" {
  description = "The domains for the oauth2 proxy cookie"
  type        = string
  default     = "[\".chrislee.local\"]"
}

variable "auth_oauth2_proxy_whitelist_domains" {
  description = "The whitelist domains for the oauth2 proxy"
  type        = string
  default     = "[\"*.chrislee.local\"]"
}

variable "auth_auth0_domain" {
  description = "The domain name for the auth0"
  type        = string
  default     = "chrislee.auth0.com"
}

variable "auth_auth0_client_id" {
  description = "The client id for the auth0"
  type        = string
  default     = ""
}

variable "auth_auth0_client_secret" {
  description = "The client secret for the auth0"
  type        = string
  sensitive   = true
}

variable "auth_host_alias_ip" {
  description = "The IP address of the host alias."
  type        = string
  default     = ""
}

variable "auth_host_alias_hostnames" {
  description = "The hostnames of the host alias comma separated. i.e. remote1.local,remote2.local"
  type        = string
  default     = ""
}
