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



variable "kibana_domain" {
  description = "The domain name for the kibana"
  type        = string
  default     = "kibana.chrislee.local"
}

variable "istio_gateway_name" {
  description = "Name of the shared Istio Gateway this module attaches its Kibana listener to."
  type        = string
  default     = "public"
}

variable "istio_gateway_namespace" {
  description = "Namespace of the shared Istio Gateway. Nothing is created there by this module except the AuthorizationPolicy, which Istio requires beside the Gateway its targetRefs names."
  type        = string
  default     = "istio-ingress"
}
