variable "elasticsearch_resource_request_memory" {
  description = "Memory request for Elasticsearch"
  type        = string
  default     = "2Gi"
}

variable "elasticsearch_resource_request_cpu" {
  description = "CPU request for Elasticsearch"
  type        = string
  default     = "1"
}

variable "elasticsearch_resource_limit_memory" {
  description = "Memory limit for Elasticsearch"
  type        = string
  default     = "2Gi"
}

variable "elasticsearch_resource_limit_cpu" {
  description = "CPU limit for Elasticsearch"
  type        = string
  default     = "1"
}

variable "elasticsearch_storage_size" {
  description = "Storage size for Elasticsearch"
  type        = string
  default     = "5Gi"
}

variable "elasticsearch_storage_class_name" {
  description = "Storage class name for Elasticsearch"
  type        = string
  default     = "longhorn"
}

variable "kibana_resource_request_memory" {
  description = "Memory request for Kibana"
  type        = string
  default     = "1Gi"
}

variable "kibana_resource_limit_memory" {
  description = "Memory limit for Kibana"
  type        = string
  default     = "1Gi"
}

variable "nginx_frontend_basic_auth_base64" {
  description = "Base64 encoded username:password for basic auth - htpasswd -nb user password | openssl base64"
  type        = string
  sensitive   = true
}


variable "kibana_ingress_class_name" {
  description = "Ingress class name for Kibana"
  type        = string
  default     = "nginx"
}

variable "kibana_ingress_enable_tls" {
  description = "Enable TLS for Kibana Ingress"
  type        = bool
  default     = false
}

variable "kibana_domain" {
  description = "The domain name for the kibana"
  type        = string
  default     = "kibana.chrislee.local"
}
