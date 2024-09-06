variable "host_machine_architecture" {
  description = "The architecture of the host machine. i.e. amd64, arm64"
  type        = string
  default     = "amd64"
}

variable "kubernetes_override_domains" {
  description = "The list of domains to be added to the CoreDNS configuration. Space delimiter. i.e. gitlab.chrislee.local registry.chrislee.local minio.chrislee.local"
  type        = string
  default     = "gitlab.chrislee.local registry.chrislee.local minio.chrislee.local"
}

variable "kubernetes_override_ip" {
  description = "The IP address of the host alias."
  type        = string
  default     = "192.168.1.100"
}


variable "nginx_frontend_basic_auth_base64" {
  description = "Base64 encoded username:password for basic auth - htpasswd -nb user password | openssl base64"
  type        = string
  sensitive   = true
}

variable "nginx_service_loadbalancer_ip" {
  description = "The IP address of the loadbalancer ip."
  type        = string
}

variable "cert_manager_acme_email" {
  description = "The email address to register certificates requested from Let's Encrypt."
  type        = string
  default     = "chris@chrislee.local"
}

variable "cert_manager_ingress_class" {
  description = "IngressClass resource for cert-manager."
  type        = string
  default     = "nginx"
}

variable "cert_manager_host_alias_ip" {
  description = "The IP address of the host alias."
  type        = string
  default     = ""
}

variable "cert_manager_host_alias_hostnames" {
  description = "The hostnames of the host alias comma separated. i.e. remote1.local,remote2.local"
  type        = string
  default     = ""
}

variable "longhorn_default_settings_default_data_path" {
  description = "Default path for storing data on a host. The default value is /var/lib/longhorn/."
  type        = string
}

variable "longhorn_ingress_class_name" {
  description = "IngressClass resource that contains ingress configuration, including the name of the Ingress controller."
  type        = string
}

variable "longhorn_ingress_host" {
  description = "Hostname of the Layer 7 load balancer."
  type        = string
}


variable "minio_tenant_pools_size" {
  description = "The capacity per volume requested per MinIO Tenant Pod."
  type        = string
  default     = "10Gi"
}

variable "minio_tenant_pools_storage_class_name" {
  description = "The storage class name to use for the MinIO Tenant Pods."
  type        = string
  default     = "longhorn"
}

variable "minio_tenant_root_user" {
  description = "The minio tenant's root username. Default to minio"
  type        = string
  default     = "minio"
}

variable "minio_tenant_default_buckets" {
  description = "The default bucket names for the tenant"
  type        = list(string)
  default = [
    "registry",
    "git-lfs",
    "runner-cache",
    "gitlab-uploads",
    "gitlab-artifacts",
    "gitlab-backups",
    "gitlab-packages",
    "tmp",
    "gitlab-mr-diffs",
    "gitlab-terraform-state",
    "gitlab-terraform-state",
    "gitlab-ci-secure-files",
    "gitlab-dependency-proxy",
    "gitlab-pages",
    "gitlab-tmp-backups",
    "gitlab-registry-storage"
  ]
}

variable "minio_tenant_user_access_key" {
  description = "The minio user access key. Default to minio"
  type        = string
  default     = "minio-user"
}

variable "minio_tenant_ingress_class_name" {
  description = "Ingress class name for the minio tenant"
  type        = string
  default     = "nginx"
}

variable "minio_tenant_ingress_api_host" {
  description = "The hostname of the minio tenant api"
  type        = string
  default     = "minio.chrislee.local"
}

variable "minio_tenant_ingress_console_host" {
  description = "The hostname of the minio tenant console"
  type        = string
  default     = "minio-console.chrislee.local"
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

variable "gitlab_persistence_storage_class_name" {
  description = "The storage class name for the gitlab persistence storage"
  type        = string
  default     = "longhorn"
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

variable "prometheus_alertmanager_slack_channel" {
  description = "The slack channel for the alertmanager"
  type        = string
}

variable "prometheus_alertmanager_slack_credentials" {
  description = "The slack credentials for the alertmanager"
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