variable "kubernetes_cluster_type" {
  description = "The type of the kubernetes cluster. i.e. kubeadm, k3s"
  type        = string
  default     = "kubeadm"
}

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

variable "ingress_enable_tls" {
  description = "Enable TLS for the services"
  type        = bool
  default     = true
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

variable "nginx_client_max_body_size" {
  description = "The maximum body size for nginx."
  type        = string
  default     = "10M"
}

variable "nginx_client_body_buffer_size" {
  description = "The client body buffer size for nginx."
  type        = string
  default     = "10M"
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

variable "gitlab_toolbox_backups_cron_persistence_size" {
  description = "The size of the toolbox backups cron persistence"
  type        = string
  default     = "20Gi"
}

variable "gitlab_toolbox_persistence_size" {
  description = "The size of the toolbox persistence"
  type        = string
  default     = "20Gi"
}

variable "gitlab_postgresql_primary_persistence_size" {
  description = "The size of the postgresql primary persistence"
  type        = string
  default     = "20Gi"
}

variable "gitlab_redis_master_persistence_size" {
  description = "The size of the redis master persistence"
  type        = string
  default     = "20Gi"
}

variable "gitlab_gitlay_persistence_size" {
  description = "The size of the gitlay persistence"
  type        = string
  default     = "20Gi"
}

variable "gitlab_runner_authentication_token" {
  description = "The authentication token for the gitlab runner. Refer https://git.math.duke.edu/gitlab/help/ci/runners/new_creation_workflow.md"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gitlab_minio_host" {
  description = "The hostname of the minio"
  type        = string
  default     = "minio.chrislee.local"
}

variable "gitlab_minio_endpoint" {
  description = "The endpoint of the minio"
  type        = string
  default     = "https://minio.chrislee.local"
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

variable "prometheus_persistence_size" {
  description = "The size of the persistence storage"
  type        = string
  default     = "5Gi"
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

variable "kibana_ingress_class_name" {
  description = "Ingress class name for Kibana"
  type        = string
  default     = "nginx"
}

variable "kibana_domain" {
  description = "The domain name for the kibana"
  type        = string
  default     = "kibana.chrislee.local"
}

variable "kubecost_token" {
  description = "Kubecost token - retrieved from https://www.kubecost.com/install.html#show-instructions"
  type        = string
  sensitive   = true
}


variable "kubecost_ingress_host" {
  description = "The host for the kubecost ingress"
  type        = string
  default     = "cost.chrislee.local"
}

variable "kubecost_ingress_class_name" {
  description = "Ingress class name for the kubecost"
  type        = string
  default     = "nginx"
}

variable "tailscale_enable" {
  description = "Enable the tailscale"
  type        = bool
  default     = false
}

variable "tailscale_auth_key" {
  description = "The auth key for the tailscale"
  type        = string
  sensitive   = true
}

variable "tailscale_advertise_routes" {
  description = "The routes to advertise to the tailscale. Comma separated. i.e. 192.86.0.0/24,192.86.1.0/24"
  type        = string
  default     = "192.86.0.0/24"
}

variable "tailscale_hostname" {
  description = "The hostname of the tailscale, which will show up in the tailnet"
  type        = string
  default     = "tailscale-kubernetes"
}

variable "wireguard_enable" {
  description = "Enable the wireguard"
  type        = bool
  default     = false
}

variable "wireguard_ingress_host" {
  description = "The host for the wireguard ingress"
  type        = string
  default     = "wireguard.chrislee.local"
}

variable "wireguard_timezone" {
  description = "The timezone for the wireguard"
  type        = string
  default     = "Australia/Melbourne"
}

variable "wireguard_port" {
  description = "The port for the wireguard"
  type        = number
  default     = 51820
}

variable "wireguard_peers" {
  description = "The peers for the wireguard"
  type        = string
  default     = 3
}

variable "argocd_domain" {
  description = "The domain name for the argocd"
  type        = string
  default     = "argocd.chrislee.local"
}

variable "argocd_ingress_class_name" {
  description = "The ingress class name for the argocd"
  type        = string
  default     = "nginx"
}

variable "argocd_ssh_known_hosts_base64" {
  description = "SSH known hosts for Git repositories - base64 encoded"
  type        = string
  default     = ""
}

variable "argocd_config_repositories_json_encoded" {
  description = "The repositories for the argocd - json encoded"
  type        = string
  default     = "[]"
}
