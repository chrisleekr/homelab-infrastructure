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
