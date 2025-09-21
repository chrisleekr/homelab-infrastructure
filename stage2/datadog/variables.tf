variable "datadog_cluster_name" {
  description = "The name of the cluster"
  type        = string
}

variable "datadog_api_key" {
  description = "The api key for the datadog"
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "The site for the datadog"
  type        = string
}

variable "datadog_app_key" {
  description = "The app key for the datadog"
  type        = string
  sensitive   = true
}
