variable "datadog_cluster_name" {
  description = "The name of the cluster for Datadog"
  type        = string
}

variable "datadog_api_key" {
  description = "The API key for Datadog"
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "The site for Datadog"
  type        = string
}

variable "datadog_app_key" {
  description = "The APP key for Datadog"
  type        = string
  sensitive   = true
}
