variable "kubernetes_cluster_type" {
  description = "The type of the kubernetes cluster. i.e. kubeadm, k3s, minikube"
  type        = string
  default     = "kubeadm"

  validation {
    condition     = contains(["kubeadm", "k3s", "minikube"], var.kubernetes_cluster_type)
    error_message = "kubernetes_cluster_type must be one of: kubeadm, k3s, minikube"
  }
}

variable "host_machine_architecture" {
  description = "The architecture of the host machine. i.e. amd64, arm64"
  type        = string
  default     = "amd64"

  validation {
    condition     = contains(["amd64", "arm64"], var.host_machine_architecture)
    error_message = "host_machine_architecture must be one of: amd64, arm64"
  }
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

  # Validate IPv4 address format per HashiCorp variable validation best practices
  validation {
    condition     = can(regex("^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.){3}(25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)$", var.kubernetes_override_ip))
    error_message = "Must be a valid IPv4 address (e.g., 192.168.1.100)"
  }
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

  # Validate IPv4 address format per HashiCorp variable validation best practices
  # Allow empty string for dynamic IP assignment by load balancer
  validation {
    condition     = var.nginx_service_loadbalancer_ip == "" || can(regex("^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.){3}(25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)$", var.nginx_service_loadbalancer_ip))
    error_message = "Must be a valid IPv4 address (e.g., 192.168.1.100) or empty string"
  }
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

variable "gitlab_minio_use_https" {
  description = "Whether to use HTTPS for the minio object storage - True or False"
  type        = string
  default     = "True"
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

  # Validate Kubernetes storage size format per Kubernetes quantity spec
  # Ref: https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/quantity/
  validation {
    condition     = can(regex("^([0-9]+(\\.[0-9]+)?)(Ei|Pi|Ti|Gi|Mi|Ki|E|P|T|G|M|K)$", var.prometheus_persistence_size))
    error_message = "Must be a valid Kubernetes storage size (e.g., 5Gi, 1.5Ti, 500Mi)"
  }
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

variable "logging_module_enable" {
  description = "Enable the logging module"
  type        = bool
  default     = true
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

  # Validate Kubernetes storage size format per Kubernetes quantity spec
  # Ref: https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/quantity/
  validation {
    condition     = can(regex("^([0-9]+(\\.[0-9]+)?)(Ei|Pi|Ti|Gi|Mi|Ki|E|P|T|G|M|K)$", var.elasticsearch_storage_size))
    error_message = "Must be a valid Kubernetes storage size (e.g., 5Gi, 1.5Ti, 500Mi)"
  }
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
  type        = string
  default     = "51820"

  # Validate port number range (1-65535)
  validation {
    condition     = can(regex("^[0-9]+$", var.wireguard_port)) && tonumber(var.wireguard_port) >= 1 && tonumber(var.wireguard_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
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


variable "argocd_rbac_policy_default" {
  description = "The default RBAC policy for ArgoCD"
  type        = string
  default     = "role:readonly"
}

variable "argocd_rbac_policy_csv" {
  description = "The RBAC policy for ArgoCD"
  type        = string
  default     = ""
}

variable "argocd_apps_repo_url" {
  description = "Git repo URL for the central ArgoCD apps repository (ApplicationSet source)"
  type        = string
  default     = ""

  validation {
    condition     = var.argocd_apps_repo_url == "" || can(regex("^(https?://|git@|ssh://)", var.argocd_apps_repo_url))
    error_message = "argocd_apps_repo_url must be empty or a valid Git URL (https://, http://, git@, or ssh://)"
  }
}

variable "auth_ingress_class_name" {
  description = "Ingress class name for the oauth2 proxy"
  type        = string
  default     = "nginx"
}

variable "auth_oauth2_proxy_host" {
  description = "The host for the oauth2 proxy"
  type        = string
  default     = "auth.chrislee.local"
}

variable "auth_oauth2_proxy_cookie_domains" {
  description = "The domains for the oauth2 proxy cookie"
  type        = string
  default     = "[\".chrislee.local\"]"
}

variable "auth_oauth2_proxy_whitelist_domains" {
  description = "The whitelist domains for the oauth2 proxy"
  type        = string
  default     = "[\"*.chrislee.local\"]"
}

variable "auth_auth0_domain" {
  description = "The domain name for the auth0"
  type        = string
  default     = "chrislee.auth0.com"
}

variable "auth_auth0_client_id" {
  description = "The client id for the auth0"
  type        = string
  default     = ""
}

variable "auth_auth0_client_secret" {
  description = "The client secret for the auth0"
  type        = string
  sensitive   = true
}


variable "sealed_secrets_enable" {
  description = "Enable the Bitnami Sealed Secrets controller"
  type        = bool
  default     = true
}

variable "sealed_secrets_key_renewal_period" {
  description = "Key renewal period for the Sealed Secrets controller (Go duration string, e.g. 720h = 30 days)"
  type        = string
  default     = "720h"

  validation {
    condition     = can(regex("^[0-9]+(h|m|s)$", var.sealed_secrets_key_renewal_period))
    error_message = "sealed_secrets_key_renewal_period must be a simple duration with a single unit, e.g. '720h', '30m', or '3600s'."
  }
}

variable "datadog_enable" {
  description = "Enable Datadog"
  type        = bool
  default     = false
}

variable "datadog_site" {
  description = "The site for Datadog"
  type        = string
}

variable "datadog_cluster_name" {
  description = "The name of the cluster for Datadog"
  type        = string
}

variable "datadog_api_key" {
  description = "The API key for Datadog"
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "The APP key for Datadog"
  type        = string
  sensitive   = true
}

# LLM Gateway variables
# Reference: https://docs.llmgateway.io/self-host

variable "llmgateway_enable" {
  description = "Enable LLM Gateway deployment"
  type        = bool
  default     = false
}

variable "llmgateway_domain" {
  description = "Domain name for LLM Gateway ingress"
  type        = string
  default     = "llm.chrislee.local"
}

variable "llmgateway_ingress_class_name" {
  description = "Ingress class name for LLM Gateway"
  type        = string
  default     = "nginx"
}

variable "llmgateway_storage_size" {
  description = "Storage size for LLM Gateway PostgreSQL data persistence"
  type        = string
  default     = "10Gi"
}

variable "llmgateway_storage_class_name" {
  description = "Storage class name for LLM Gateway persistent volume"
  type        = string
  default     = "longhorn"
}

variable "llmgateway_auth_secret" {
  description = "AUTH_SECRET for LLM Gateway session management. Generate with: openssl rand -hex 32"
  type        = string
  sensitive   = true
  default     = ""

  # Validate auth_secret length when provided
  # Fail fast at plan time rather than discovering issues post-deployment
  validation {
    condition     = var.llmgateway_auth_secret == "" || length(var.llmgateway_auth_secret) >= 32
    error_message = "llmgateway_auth_secret must be at least 32 characters. Generate with: openssl rand -hex 32"
  }
}

variable "llmgateway_image_tag" {
  description = "Docker image tag for LLM Gateway. Use specific version from https://github.com/theopenco/llmgateway/releases"
  type        = string
  default     = "latest"
}

variable "llmgateway_replicas" {
  description = "Number of LLM Gateway replicas. Note: Multiple replicas require ReadWriteMany storage or separate PVCs"
  type        = number
  default     = 1

  validation {
    condition     = var.llmgateway_replicas >= 1
    error_message = "llmgateway_replicas must be at least 1"
  }
}

variable "llmgateway_admin_emails" {
  description = "Comma-separated list of email addresses that have admin access to LLM Gateway admin dashboard. Reference: https://github.com/theopenco/llmgateway/blob/main/apps/api/src/routes/user.ts"
  type        = string
  sensitive   = true
  default     = ""
}
