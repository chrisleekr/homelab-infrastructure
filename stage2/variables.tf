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
  description = "Space-delimited list of domains added to the CoreDNS configuration. Each entry must be a lowercase FQDN. Example: \"gitlab.chrislee.local registry.chrislee.local minio.chrislee.local\""
  type        = string
  default     = "gitlab.chrislee.local registry.chrislee.local minio.chrislee.local"

  validation {
    condition = alltrue([
      for d in split(" ", var.kubernetes_override_domains) :
      can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", d))
    ])
    error_message = "kubernetes_override_domains must be a non-empty, single-space-delimited list of lowercase FQDNs (e.g., \"gitlab.chrislee.local registry.chrislee.local\"). No leading/trailing/multiple spaces, no uppercase, no empty entries."
  }
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

  # Validate nginx size format per https://nginx.org/en/docs/syntax.html
  validation {
    condition     = can(regex("^[0-9]+[kKmMgG]?$", var.nginx_client_max_body_size))
    error_message = "Must be a valid nginx size (e.g., 10M, 512k, 1G, or plain bytes like 1048576)"
  }
}

variable "nginx_client_body_buffer_size" {
  description = "The client body buffer size for nginx."
  type        = string
  default     = "10M"

  # Validate nginx size format per https://nginx.org/en/docs/syntax.html
  validation {
    condition     = can(regex("^[0-9]+[kKmMgG]?$", var.nginx_client_body_buffer_size))
    error_message = "Must be a valid nginx size (e.g., 10M, 512k, 1G, or plain bytes like 1048576)"
  }
}

variable "cert_manager_acme_email" {
  description = "The email address to register certificates requested from Let's Encrypt."
  type        = string
  default     = "chris@chrislee.local"

  # Validate basic email format per RFC 5321
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.cert_manager_acme_email))
    error_message = "Must be a valid email address (e.g., user@example.com)"
  }
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

  # Validate Kubernetes storage size format per Kubernetes quantity spec
  # Ref: https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/quantity/
  validation {
    condition     = can(regex("^([0-9]+(\\.[0-9]+)?)(Ei|Pi|Ti|Gi|Mi|Ki|E|P|T|G|M|K)$", var.minio_tenant_pools_size))
    error_message = "Must be a valid Kubernetes storage size (e.g., 10Gi, 1.5Ti, 500Mi)"
  }
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
  default     = "30Gi"

  # Validate Kubernetes storage size format per Kubernetes quantity spec
  # Ref: https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/quantity/
  validation {
    condition     = can(regex("^([0-9]+(\\.[0-9]+)?)(Ei|Pi|Ti|Gi|Mi|Ki|E|P|T|G|M|K)$", var.gitlab_toolbox_backups_cron_persistence_size))
    error_message = "Must be a valid Kubernetes storage size (e.g., 30Gi, 1.5Ti, 500Mi)"
  }
}

variable "gitlab_toolbox_persistence_size" {
  description = "The size of the toolbox persistence"
  type        = string
  default     = "20Gi"

  # Validate Kubernetes storage size format per Kubernetes quantity spec
  # Ref: https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/quantity/
  validation {
    condition     = can(regex("^([0-9]+(\\.[0-9]+)?)(Ei|Pi|Ti|Gi|Mi|Ki|E|P|T|G|M|K)$", var.gitlab_toolbox_persistence_size))
    error_message = "Must be a valid Kubernetes storage size (e.g., 20Gi, 1.5Ti, 500Mi)"
  }
}

variable "gitlab_postgresql_primary_persistence_size" {
  description = "The size of the postgresql primary persistence"
  type        = string
  default     = "20Gi"

  # Validate Kubernetes storage size format per Kubernetes quantity spec
  # Ref: https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/quantity/
  validation {
    condition     = can(regex("^([0-9]+(\\.[0-9]+)?)(Ei|Pi|Ti|Gi|Mi|Ki|E|P|T|G|M|K)$", var.gitlab_postgresql_primary_persistence_size))
    error_message = "Must be a valid Kubernetes storage size (e.g., 20Gi, 1.5Ti, 500Mi)"
  }
}

variable "gitlab_redis_master_persistence_size" {
  description = "The size of the redis master persistence"
  type        = string
  default     = "20Gi"

  # Validate Kubernetes storage size format per Kubernetes quantity spec
  # Ref: https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/quantity/
  validation {
    condition     = can(regex("^([0-9]+(\\.[0-9]+)?)(Ei|Pi|Ti|Gi|Mi|Ki|E|P|T|G|M|K)$", var.gitlab_redis_master_persistence_size))
    error_message = "Must be a valid Kubernetes storage size (e.g., 20Gi, 1.5Ti, 500Mi)"
  }
}

variable "gitlab_gitaly_persistence_size" {
  description = "The size of the gitaly persistence"
  type        = string
  # Backs a StatefulSet volumeClaimTemplate, which cannot be updated. Must match gitaly's existing
  # volume, which is 50Gi because the misspelled "gitlay" key left the chart default in force.
  default = "50Gi"

  # Validate Kubernetes storage size format per Kubernetes quantity spec
  # Ref: https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/quantity/
  validation {
    condition     = can(regex("^([0-9]+(\\.[0-9]+)?)(Ei|Pi|Ti|Gi|Mi|Ki|E|P|T|G|M|K)$", var.gitlab_gitaly_persistence_size))
    error_message = "Must be a valid Kubernetes storage size (e.g., 50Gi, 1.5Ti, 500Mi)"
  }
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
  type        = number
  default     = 3

  validation {
    condition     = var.wireguard_peers >= 1 && var.wireguard_peers == floor(var.wireguard_peers)
    error_message = "wireguard_peers must be a positive integer (e.g., 1, 2, 3)."
  }
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

variable "argocd_image_updater_enable" {
  description = "Enable ArgoCD Image Updater"
  type        = bool
  default     = false
}

variable "container_registry_prefix" {
  description = "Registry host that ArgoCD Image Updater scans. Must match the image prefix used in the ArgoCD app manifests."
  type        = string
  default     = "registry.chrislee.local"

  validation {
    # Host only. A scheme here would never match the image prefix in the manifests.
    condition     = can(regex("^[a-z0-9.-]+(:[0-9]+)?$", var.container_registry_prefix))
    error_message = "container_registry_prefix must be a registry host such as registry.example.com, with no scheme and no path"
  }
}

variable "container_registry_api_url" {
  description = "Base URL of the registry API used to list tags and read manifests"
  type        = string
  default     = "https://registry.chrislee.local"

  validation {
    condition     = can(regex("^https?://", var.container_registry_api_url))
    error_message = "container_registry_api_url must start with https:// or http://"
  }
}

variable "container_registry_credentials" {
  description = "Registry read credentials as 'username:token'. GitLab deploy token with the read_registry scope."
  type        = string
  sensitive   = true
  default     = ""

  validation {
    # Empty is allowed so the module can stay disabled. The module enforces non-empty when enabled.
    condition     = var.container_registry_credentials == "" || can(regex("^[^:]+:[^:]+$", var.container_registry_credentials))
    error_message = "container_registry_credentials must be empty or in 'username:token' form"
  }
}

variable "argocd_apps_git_username" {
  description = "Username for the git write-back token. For a GitLab project access token this is the token name."
  type        = string
  default     = "argocd-image-updater"

  validation {
    condition     = length(var.argocd_apps_git_username) > 0
    error_message = "argocd_apps_git_username must not be empty"
  }
}

variable "argocd_apps_git_password" {
  description = "Git write-back token for the argocd-apps repository. GitLab project access token with the write_repository scope."
  type        = string
  sensitive   = true
  default     = ""

  # No format validation: token shapes vary by GitLab version. The module enforces non-empty when enabled.
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

  # Validate Datadog site per https://docs.datadoghq.com/getting_started/site/
  validation {
    condition     = contains(["datadoghq.com", "us3.datadoghq.com", "us5.datadoghq.com", "datadoghq.eu", "ap1.datadoghq.com", "ap2.datadoghq.com", "ddog-gov.com"], var.datadog_site)
    error_message = "datadog_site must be a valid Datadog site: datadoghq.com, us3.datadoghq.com, us5.datadoghq.com, datadoghq.eu, ap1.datadoghq.com, ap2.datadoghq.com, or ddog-gov.com"
  }
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

# LiteLLM variables
# Reference: https://docs.litellm.ai/docs/proxy/deploy

variable "litellm_enable" {
  description = "Enable the LiteLLM proxy deployment"
  type        = bool
  default     = false
}

variable "litellm_domain" {
  description = "Domain name for the LiteLLM ingress. Both the API and the admin UI are served from this single host"
  type        = string
  default     = "litellm.chrislee.local"
}

variable "litellm_ingress_class_name" {
  description = "Ingress class name for the LiteLLM ingresses"
  type        = string
  default     = "nginx"
}

variable "litellm_ui_paths" {
  description = "URL path prefixes routed to the oauth2-proxy protected ingress. /litellm-asset-prefix serves the console JS and CSS, and /fallback/login plus /login are the console's login page and its credential POST target. /docs, /redoc, /openapi.json, /routes, /config/yaml and /public are introspection surfaces no API client needs. Anything omitted here falls through to the unauthenticated API ingress"
  type        = list(string)
  default = [
    "/ui", "/sso", "/litellm-asset-prefix",
    "/fallback/login", "/login",
    "/docs", "/redoc", "/openapi.json", "/routes",
    "/config/yaml", "/public",
  ]
}

variable "litellm_chart_version" {
  description = "litellm-helm chart version. The chart version tracks appVersion, so bump it together with litellm_image_tag"
  type        = string
  default     = "1.89.2"
}

variable "litellm_image_tag" {
  description = "Tag for ghcr.io/berriai/litellm-database. No 'v' prefix: the chart's own default is the bare appVersion"
  type        = string
  default     = "1.89.2"
}

variable "litellm_postgres_image_tag" {
  description = "Tag for the upstream postgres image backing LiteLLM. Must be an -alpine tag: the StatefulSet sets fs_group = 70, which is the alpine postgres gid. Prisma migrations verified against 18.4-alpine"
  type        = string
  default     = "18.4-alpine"

  validation {
    condition     = var.litellm_postgres_image_tag != "latest" && endswith(var.litellm_postgres_image_tag, "-alpine")
    error_message = "litellm_postgres_image_tag must be a pinned -alpine tag: the StatefulSet sets fs_group = 70, the alpine postgres gid (Debian images use 999)"
  }
}

variable "litellm_replicas" {
  description = "Number of LiteLLM proxy replicas"
  type        = number
  default     = 1

  validation {
    condition     = var.litellm_replicas >= 1
    error_message = "litellm_replicas must be at least 1"
  }
}

variable "litellm_storage_class_name" {
  description = "Storage class name for the LiteLLM Postgres persistent volume"
  type        = string
  default     = "longhorn"
}

variable "litellm_storage_size" {
  description = "Storage size for the LiteLLM Postgres persistent volume"
  type        = string
  default     = "10Gi"

  # Validate Kubernetes storage size format per Kubernetes quantity spec
  # Ref: https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/quantity/
  validation {
    condition     = can(regex("^([0-9]+(\\.[0-9]+)?)(Ei|Pi|Ti|Gi|Mi|Ki|E|P|T|G|M|K)$", var.litellm_storage_size))
    error_message = "Must be a valid Kubernetes storage size (e.g., 10Gi, 1.5Ti, 500Mi)"
  }
}

variable "litellm_master_key" {
  description = "LiteLLM admin and API superuser key, injected as PROXY_MASTER_KEY. Generate with: echo \"sk-$(openssl rand -hex 24)\""
  type        = string
  sensitive   = true
  default     = ""

  # Fail fast at plan time rather than discovering a rejected key post-deployment
  validation {
    condition     = var.litellm_master_key == "" || startswith(var.litellm_master_key, "sk-")
    error_message = "litellm_master_key must start with 'sk-'"
  }
}

variable "litellm_salt_key" {
  description = "Encrypts provider credentials stored in the database. WRITE ONCE: rotating it makes every stored credential permanently unreadable. Generate with: echo \"sk-$(openssl rand -hex 24)\""
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.litellm_salt_key == "" || startswith(var.litellm_salt_key, "sk-")
    error_message = "litellm_salt_key must start with 'sk-'"
  }
}

variable "litellm_db_password" {
  description = "Password for the module-owned LiteLLM Postgres. Restricted to URI-safe characters: the chart builds db.url as postgresql://user:password@host/db, and a reserved character would silently corrupt it. Generate with: openssl rand -hex 16"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition = var.litellm_db_password == "" || (
      length(var.litellm_db_password) >= 16 &&
      can(regex("^[A-Za-z0-9_.~-]+$", var.litellm_db_password))
    )
    error_message = "litellm_db_password must be at least 16 characters using only A-Z a-z 0-9 _ . ~ - (it is interpolated into a postgresql:// URI). Generate with: openssl rand -hex 16"
  }
}

variable "litellm_provider_secrets" {
  description = "Upstream provider API keys, delivered as one JSON object and exported to the pod as environment variables. proxy_config references them as os.environ/<KEY>. Adding a provider needs no Terraform change"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "cloudflare_tunnel_enable" {
  description = "Deploy the remotely-managed Cloudflare Tunnel connector (cloudflared) into the cluster."
  type        = bool
  default     = false
}

variable "cloudflare_tunnel_token" {
  description = "Cloudflare Tunnel token (sensitive). Not self-generated; Cloudflare issues it per tunnel. Get it: dashboard > Zero Trust > Networks > Tunnels > Create a tunnel > cloudflared > name it > Save; on the install screen copy the value after --token (the eyJ... string)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_tunnel_chart_version" {
  description = "cloudflare-tunnel-remote Helm chart version. Pinned per repo convention. Reference: helm show chart cloudflare/cloudflare-tunnel-remote"
  type        = string
  default     = "0.1.2" # empty would resolve to latest chart and defeat pinning
}

variable "cloudflare_tunnel_image_tag" {
  description = "cloudflared image tag to pin. Empty uses the chart default. Reference: https://github.com/cloudflare/cloudflared/releases"
  type        = string
  default     = ""
}

variable "cloudflare_tunnel_replica_count" {
  description = "Number of cloudflared replicas. HA only; do not autoscale (downscaling breaks live connections)."
  type        = number
  default     = 2
}

# OmniRoute variables
# Reference: https://github.com/diegosouzapw/OmniRoute

variable "omniroute_enable" {
  description = "Enable the OmniRoute AI gateway deployment"
  type        = bool
  default     = false
}

variable "omniroute_domain" {
  description = "Domain name for the OmniRoute ingress. Both the open /api/v1 surface and the gated dashboard are served from this single host"
  type        = string
  default     = "omniroute.chrislee.local"
}

variable "omniroute_ingress_class_name" {
  description = "Ingress class name for the OmniRoute ingresses"
  type        = string
  default     = "nginx"
}

variable "omniroute_public_paths" {
  description = "URL path prefixes routed to the open, unauthenticated API ingress. Everything else, the dashboard at / plus any /api path omitted here, falls through to the oauth2-proxy-gated ingress. Default is the OpenAI-compatible base path only. Provider OAuth/webhook callbacks and cert-manager's /.well-known are opt-in additions; re-verify the exact set against a running container"
  type        = list(string)
  default     = ["/api/v1"]
}

variable "omniroute_gated_api_paths" {
  description = "Admin subpaths under the open /api/v1 prefix pulled back behind oauth2-proxy as defense in depth (management, agents, accounts, registered-keys). OpenAI-compatible clients never call these, so gating them costs model traffic nothing. Set to [] to disable"
  type        = list(string)
  default = [
    "/api/v1/management",
    "/api/v1/agents",
    "/api/v1/accounts",
    "/api/v1/registered-keys",
  ]
}

variable "omniroute_chart_version" {
  description = "omniroute Helm chart version from https://chrisleekr.github.io/helm-charts. The chart version tracks appVersion, so bump it together with omniroute_image_tag"
  type        = string
  default     = "0.1.1"
}

variable "omniroute_image_tag" {
  description = "Tag for diegosouzapw/omniroute. Empty defaults to the chart appVersion. Use the -web flavor (e.g. 3.8.48-web) for web-cookie providers like gemini-web or claude-web"
  type        = string
  default     = ""
}

variable "omniroute_storage_class_name" {
  description = "Storage class name for the OmniRoute SQLite persistent volume"
  type        = string
  default     = "longhorn"
}

variable "omniroute_storage_size" {
  description = "Storage size for the OmniRoute SQLite persistent volume"
  type        = string
  default     = "5Gi"

  # Validate Kubernetes storage size format per Kubernetes quantity spec
  # Ref: https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/quantity/
  validation {
    condition     = can(regex("^([0-9]+(\\.[0-9]+)?)(Ei|Pi|Ti|Gi|Mi|Ki|E|P|T|G|M|K)$", var.omniroute_storage_size))
    error_message = "Must be a valid Kubernetes storage size (e.g., 5Gi, 1.5Ti, 500Mi)"
  }
}

variable "omniroute_initial_password" {
  description = "Initial dashboard admin password, injected as INITIAL_PASSWORD. Only used on first boot; change it from the dashboard afterwards. Generate with: openssl rand -base64 24"
  type        = string
  sensitive   = true
  default     = ""
}

variable "omniroute_jwt_secret" {
  description = "Signs dashboard session tokens, injected as JWT_SECRET. Rotatable: rotating only logs users out. Generate with: openssl rand -hex 32"
  type        = string
  sensitive   = true
  default     = ""
}

variable "omniroute_api_key_secret" {
  description = "Encrypts stored provider API keys, injected as API_KEY_SECRET. WRITE ONCE: rotating it makes every stored provider key permanently unreadable. Generate with: openssl rand -hex 32"
  type        = string
  sensitive   = true
  default     = ""
}

variable "omniroute_storage_encryption_key" {
  description = "Encrypts the OmniRoute database at rest, injected as STORAGE_ENCRYPTION_KEY. WRITE ONCE: rotating it makes an already-encrypted database unreadable. Generate with: openssl rand -hex 32"
  type        = string
  sensitive   = true
  default     = ""
}
