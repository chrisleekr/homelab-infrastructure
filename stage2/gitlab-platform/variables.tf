## https://docs.gitlab.com/charts/charts/globals#configure-host-settings
variable "host_machine_architecture" {
  description = "The architecture of the host machine. i.e. amd64, arm64"
  type        = string
  default     = "amd64"
}

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
  description = "If set to true, you will need to ensure the NGINX chart has access to the certificates. In cases where you have TLS-termination in front of your Ingresses, you probably want to look at global.ingress.tls.enabled. Set to false for external URLs to use http:// instead of https."
  type        = bool
  default     = true
}

variable "gitlab_global_hosts_external_ip" {
  description = "Set the external IP address that will be claimed from the provider. This will be templated into the NGINX chart, in place of the more complex nginx.service.loadBalancerIP."
  type        = string
  default     = ""
}

variable "gitlab_global_ingress_provider" {
  description = "Global setting that defines the Ingress provider to use. nginx is used as the default provider."
  type        = string
  default     = "nginx"

}
variable "gitlab_global_ingress_class" {
  description = "Global setting that controls kubernetes.io/ingress.class annotation or spec.IngressClassName in Ingress resources. Set to none to disable, or \"\" for empty. Note: for none or \"\", set nginx-ingress.enabled=false to prevent the charts from deploying unnecessary Ingress resources."
  type        = string
  default     = "nginx"
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
