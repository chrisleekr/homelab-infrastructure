variable "longhorn_default_settings_default_data_path" {
  description = "Default path for storing data on a host. The default value is /var/lib/longhorn/."
  type        = string
  default     = "/var/lib/longhorn"
}


variable "longhorn_ingress_host" {
  description = "Hostname of the Layer 7 load balancer."
  type        = string
}



variable "istio_gateway_name" {
  description = "Gateway resource this module's ListenerSet attaches to"
  type        = string
  default     = "public"
}

variable "istio_gateway_namespace" {
  description = "Namespace of the Gateway, and of the AuthorizationPolicy that targets it"
  type        = string
  default     = "istio-ingress"
}
