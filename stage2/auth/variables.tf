variable "prometheus_namespace" {
  description = "The namespace for the prometheus"
  type        = string
  default     = "monitoring"
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

variable "istio_gateway_name" {
  description = "Name of the shared Istio Gateway this module contributes its listener to."
  type        = string
  default     = "public"
}

variable "istio_gateway_namespace" {
  description = "Namespace of the shared Istio Gateway. Nothing is created there by this module, but the ListenerSet parentRef needs the name."
  type        = string
  default     = "istio-ingress"
}
