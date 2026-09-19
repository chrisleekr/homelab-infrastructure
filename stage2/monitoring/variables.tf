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

variable "prometheus_persistence_size" {
  description = "The size of the persistence storage"
  type        = string
  default     = "10Gi"
}

variable "prometheus_alertmanager_slack_channel" {
  description = "Slack channel name without a leading '#'. The Alertmanager values template adds it."
  type        = string

  validation {
    condition     = can(regex("^[^#[:space:]][^[:space:]]*$", var.prometheus_alertmanager_slack_channel))
    error_message = "Give a non-empty channel name with no whitespace and no leading '#'. The template prepends the '#', so '#alerts' renders as '##alerts' and chat.postMessage returns channel_not_found."
  }
}

variable "prometheus_alertmanager_slack_credentials" {
  description = "Slack bot token, xoxb-, with the chat:write scope. Alertmanager sends it as a bearer token to chat.postMessage, so an incoming webhook URL will not work."
  type        = string
  sensitive   = true
}

variable "prometheus_minio_job_bearer_token" {
  description = "The bearer token for the minio job scraper"
  type        = string
  sensitive   = true
}

variable "prometheus_minio_job_node_bearer_token" {
  description = "The bearer token for the minio job node scraper"
  type        = string
  sensitive   = true
}

variable "prometheus_minio_job_bucket_bearer_token" {
  description = "The bearer token for the minio job bucket scraper"
  type        = string
  sensitive   = true
}

variable "prometheus_minio_job_resource_bearer_token" {
  description = "The bearer token for the minio job resource scraper"
  type        = string
  sensitive   = true
}

# ElastAlert2

variable "elastalert2_elasticsearch_enabled" {
  description = "Enable the elastalert2"
  type        = bool
  default     = true
}

variable "elastalert2_elasticsearch_host" {
  description = "The host for the elastalert2"
  type        = string
}

variable "elastalert2_elasticsearch_port" {
  description = "The port for the elastalert2"
  type        = number
}

variable "elastalert2_elasticsearch_username" {
  description = "The username for the elastalert2"
  type        = string
}

variable "elastalert2_elasticsearch_password" {
  description = "The password for the elastalert2"
  type        = string
  sensitive   = true
}

variable "istio_gateway_name" {
  description = "Name of the shared Istio Gateway this module contributes its listeners to."
  type        = string
  default     = "public"
}

variable "istio_gateway_namespace" {
  description = "Namespace of the shared Istio Gateway. The AuthorizationPolicy is created here, because Istio requires a policy to sit beside the resource its targetRefs names."
  type        = string
  default     = "istio-ingress"
}
