## https://docs.gitlab.com/charts/charts/globals#configure-host-settings
variable "gitlab_global_hosts_domain" {
  description = "The base domain. GitLab and Registry will be exposed on the subdomain of this setting. This defaults to example.com, but is not used for hosts that have their name property configured. See the gitlab.name, minio.name, and registry.name sections below."
  type        = string
  default     = "chrislee.local"
}

variable "gitlab_global_hosts_host_suffix" {
  description = "Defaults to being unset. If set, the suffix is appended to the subdomain with a hyphen. The example below would result in using external hostnames like gitlab-staging.example.com and registry-staging.example.com:"
  type        = string
  default     = ""
}

variable "gitlab_global_hosts_https" {
  description = "Whether GitLab builds its external URLs as https. TLS is terminated at the Istio gateway, so this governs the scheme GitLab advertises, not certificate handling."
  type        = bool
  default     = true
}

variable "gitlab_global_hosts_external_ip" {
  description = "External IP advertised in global.hosts.externalIP. The bundled ingress controller that would have claimed it is disabled, so this only affects values the chart renders from that field."
  type        = string
  default     = ""
}

variable "gitlab_global_ingress_provider" {
  description = "Global setting that defines the Ingress provider. Inert while every GitLab component disables its own Ingress, but the chart still reads it for its ingress.class.name helper."
  type        = string
  default     = "nginx"

}
variable "gitlab_global_ingress_class" {
  description = "Global setting that controls the ingress class name in Ingress resources. Inert while every GitLab component disables its own Ingress, but the chart still reads it for its ingress.class.name helper."
  type        = string
  default     = "nginx"
}

variable "gitlab_global_ingress_enable_tls" {
  description = "Enable TLS for the services"
  type        = bool
  default     = true
}

variable "gitlab_certmanager_issuer_email" {
  description = "The email address to register certificates requested from Let's Encrypt."
  type        = string
  default     = ""
}

variable "gitlab_time_zone" {
  description = "The timezone to use for GitLab. This is used to set the timezone in the GitLab application."
  type        = string
  default     = "Australia/Melbourne"
}

variable "gitlab_minio_host" {
  description = "The hostname of the minio object storage"
  type        = string
  default     = "minio.chrislee.local"
}

variable "gitlab_minio_endpoint" {
  description = "The endpoint of the minio object storage"
  type        = string
  default     = "http://minio.chrislee.local"
}

variable "gitlab_minio_use_https" {
  description = "Whether to use HTTPS for the minio object storage - True or False"
  type        = string
  default     = "False"
}

variable "gitlab_minio_access_key" {
  description = "The access key of the minio object storage"
  type        = string
  default     = "minio-user"
}

variable "gitlab_minio_secret_key" {
  description = "The secret key of the minio object storage"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gitlab_persistence_storage_class_name" {
  description = "The storage class name for the GitLab persistence"
  type        = string
  default     = "longhorn"
}

variable "gitlab_toolbox_backups_cron_persistence_size" {
  description = "The size of the toolbox backups cron persistence"
  type        = string
  default     = "30Gi"
}

variable "gitlab_toolbox_persistence_size" {
  description = "The size of the toolbox persistence"
  type        = string
  default     = "20Gi"
}

variable "gitlab_valkey_persistence_size" {
  description = "The size of the Valkey data volume."
  type        = string
  default     = "2Gi"
}

variable "gitlab_postgres_storage_size" {
  description = "The size of the CloudNativePG cluster data volume."
  type        = string
  default     = "20Gi"
}

variable "gitlab_gitaly_persistence_size" {
  description = "The size of the gitaly persistence"
  type        = string
  # Backs a StatefulSet volumeClaimTemplate, which cannot be updated. Must match gitaly's existing
  # volume, which is 50Gi because the misspelled "gitlay" key left the chart default in force.
  default = "50Gi"
}

variable "gitlab_runner_authentication_token" {
  description = "The authentication token for the gitlab runner. Refer https://git.math.duke.edu/gitlab/help/ci/runners/new_creation_workflow.md"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gitlab_auth0_client_id" {
  description = "The Auth0 client ID for GitLab authentication"
  type        = string
  default     = ""
}

variable "gitlab_auth0_client_secret" {
  description = "The Auth0 client secret for GitLab authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gitlab_auth0_domain" {
  description = "The Auth0 domain for GitLab authentication"
  type        = string
  default     = "chrislee.auth0.com"
}

variable "istio_gateway_name" {
  description = "Name of the shared Istio Gateway this module contributes its listeners to."
  type        = string
  default     = "public"
}

variable "istio_gateway_namespace" {
  description = "Namespace of the shared Istio Gateway. Listeners are contributed from this module's own namespace, so nothing is created here, but the ListenerSet parentRef needs the name."
  type        = string
  default     = "istio-ingress"
}
