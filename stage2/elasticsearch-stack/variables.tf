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
  default     = "4Gi"
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
