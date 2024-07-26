variable "nginx_frontend_basic_auth_base64" {
  description = "Base64 encoded username:password for basic auth - htpasswd -nb user password | openssl base64"
  type        = string
  sensitive   = true
}

variable "prometheus_alertmanager_domain" {
  description = "The domain name for the alertmanager"
  type        = string
  default     = "alertmanager.chrislee.local"
}

variable "prometheus_grafana_domain" {
  description = "The domain name for the grafana"
  type        = string
  default     = "grafana.chrislee.local"
}

variable "prometehus_grafana_storage_class" {
  description = "The storage class for the grafana"
  type        = string
  default     = "longhorn"
}

variable "prometheus_ingress_class_name" {
  description = "Ingress class name for the prometheus stack"
  type        = string
  default     = "nginx"
}

variable "prometheus_prometheus_domain" {
  description = "The domain name for the prometheus"
  type        = string
  default     = "prometheus.chrislee.local"
}

variable "prometheus_persistence_storage_class_name" {
  description = "The storage class name for the prometheus persistence storage"
  type        = string
  default     = "longhorn"
}
