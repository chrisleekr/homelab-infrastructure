module "kubernetes" {
  source = "./kubernetes"

  kubernetes_cluster_type     = var.kubernetes_cluster_type
  kubernetes_override_domains = var.kubernetes_override_domains
  kubernetes_override_ip      = var.kubernetes_override_ip
}

module "nginx" {
  depends_on = [module.kubernetes]

  source                        = "./nginx"
  nginx_service_loadbalancer_ip = var.nginx_service_loadbalancer_ip
  nginx_client_max_body_size    = var.nginx_client_max_body_size
  nginx_client_body_buffer_size = var.nginx_client_body_buffer_size

  wireguard_port = var.wireguard_port
}

module "auth" {
  depends_on = [module.nginx, module.monitoring, module.cert_manager_letsencrypt]
  source     = "./auth"

  prometheus_namespace                = module.monitoring.monitoring_namespace
  auth_ingress_class_name             = var.auth_ingress_class_name
  auth_ingress_enable_tls             = var.ingress_enable_tls
  auth_oauth2_proxy_host              = var.auth_oauth2_proxy_host
  auth_oauth2_proxy_cookie_domains    = var.auth_oauth2_proxy_cookie_domains
  auth_oauth2_proxy_whitelist_domains = var.auth_oauth2_proxy_whitelist_domains
  auth_auth0_domain                   = var.auth_auth0_domain
  auth_auth0_client_id                = var.auth_auth0_client_id
  auth_auth0_client_secret            = var.auth_auth0_client_secret
  auth_host_alias_ip                  = var.cert_manager_host_alias_ip
  auth_host_alias_hostnames           = var.cert_manager_host_alias_hostnames
}


module "cert_manager_letsencrypt" {
  depends_on = [module.nginx]
  source     = "./cert-manager-letsencrypt"

  cert_manager_acme_email           = var.cert_manager_acme_email
  cert_manager_ingress_class        = var.cert_manager_ingress_class
  cert_manager_host_alias_ip        = var.cert_manager_host_alias_ip
  cert_manager_host_alias_hostnames = var.cert_manager_host_alias_hostnames
}

module "longhorn_storage" {
  depends_on = [module.cert_manager_letsencrypt]

  source = "./longhorn-storage"

  nginx_frontend_basic_auth_base64            = var.nginx_frontend_basic_auth_base64
  longhorn_default_settings_default_data_path = var.longhorn_default_settings_default_data_path
  longhorn_ingress_class_name                 = var.longhorn_ingress_class_name
  longhorn_ingress_host                       = var.longhorn_ingress_host
  longhorn_ingress_enable_tls                 = var.ingress_enable_tls
  auth_oauth2_proxy_host                      = var.auth_oauth2_proxy_host
}

module "minio_object_storage" {
  depends_on = [module.longhorn_storage]

  source = "./minio-object-storage"

  nginx_frontend_basic_auth_base64      = var.nginx_frontend_basic_auth_base64
  minio_tenant_pools_size               = var.minio_tenant_pools_size
  minio_tenant_pools_storage_class_name = var.minio_tenant_pools_storage_class_name
  minio_tenant_root_user                = var.minio_tenant_root_user
  minio_tenant_default_buckets          = var.minio_tenant_default_buckets
  minio_tenant_user_access_key          = var.minio_tenant_user_access_key
  minio_tenant_ingress_class_name       = var.minio_tenant_ingress_class_name
  minio_tenant_ingress_api_host         = var.minio_tenant_ingress_api_host
  minio_tenant_ingress_console_host     = var.minio_tenant_ingress_console_host
  minio_tenant_ingress_enable_tls       = var.ingress_enable_tls
  auth_oauth2_proxy_host                = var.auth_oauth2_proxy_host
}

module "gitlab_platform" {
  # Gitlab does not work in ARM64. Skip this module if the host machine architecture is ARM64
  count = var.host_machine_architecture == "amd64" ? 1 : 0

  depends_on = [module.minio_object_storage]
  source     = "./gitlab-platform"

  host_machine_architecture = var.host_machine_architecture

  gitlab_global_hosts_domain       = var.gitlab_global_hosts_domain
  gitlab_global_hosts_host_suffix  = var.gitlab_global_hosts_host_suffix
  gitlab_global_hosts_external_ip  = var.gitlab_global_hosts_external_ip
  gitlab_global_ingress_provider   = var.gitlab_global_ingress_provider
  gitlab_global_ingress_class      = var.gitlab_global_ingress_class
  gitlab_global_ingress_enable_tls = var.ingress_enable_tls


  gitlab_certmanager_issuer_email = var.gitlab_certmanager_issuer_email

  gitlab_minio_host       = var.gitlab_minio_host
  gitlab_minio_endpoint   = var.gitlab_minio_endpoint
  gitlab_minio_use_https  = var.gitlab_minio_use_https
  gitlab_minio_access_key = var.minio_tenant_user_access_key
  gitlab_minio_secret_key = module.minio_object_storage.minio_tenant_user_secret_key

  gitlab_persistence_storage_class_name        = var.gitlab_persistence_storage_class_name
  gitlab_toolbox_backups_cron_persistence_size = var.gitlab_toolbox_backups_cron_persistence_size
  gitlab_toolbox_persistence_size              = var.gitlab_toolbox_persistence_size

  gitlab_postgresql_primary_persistence_size = var.gitlab_postgresql_primary_persistence_size
  gitlab_redis_master_persistence_size       = var.gitlab_redis_master_persistence_size
  gitlab_gitlay_persistence_size             = var.gitlab_gitlay_persistence_size

  gitlab_runner_authentication_token = var.gitlab_runner_authentication_token

  gitlab_auth0_client_id     = var.auth_auth0_client_id
  gitlab_auth0_client_secret = var.auth_auth0_client_secret
  gitlab_auth0_domain        = var.auth_auth0_domain
}


module "logging" {
  count      = var.logging_module_enable ? 1 : 0
  depends_on = [module.cert_manager_letsencrypt]
  source     = "./logging"

  elasticsearch_resource_request_memory = var.elasticsearch_resource_request_memory
  elasticsearch_resource_request_cpu    = var.elasticsearch_resource_request_cpu
  elasticsearch_resource_limit_memory   = var.elasticsearch_resource_limit_memory
  elasticsearch_resource_limit_cpu      = var.elasticsearch_resource_limit_cpu
  elasticsearch_storage_size            = var.elasticsearch_storage_size
  elasticsearch_storage_class_name      = var.elasticsearch_storage_class_name

  kibana_resource_request_memory   = var.kibana_resource_request_memory
  kibana_resource_limit_memory     = var.kibana_resource_limit_memory
  kibana_ingress_class_name        = var.kibana_ingress_class_name
  kibana_ingress_enable_tls        = var.ingress_enable_tls
  kibana_domain                    = var.kibana_domain
  nginx_frontend_basic_auth_base64 = var.nginx_frontend_basic_auth_base64
  auth_oauth2_proxy_host           = var.auth_oauth2_proxy_host
}

module "monitoring" {
  depends_on = [module.cert_manager_letsencrypt, module.logging]
  source     = "./monitoring"

  nginx_frontend_basic_auth_base64 = var.nginx_frontend_basic_auth_base64
  prometheus_alertmanager_domain   = var.prometheus_alertmanager_domain
  prometheus_grafana_domain        = var.prometheus_grafana_domain
  prometheus_ingress_class_name    = var.prometheus_ingress_class_name
  prometheus_ingress_enable_tls    = var.ingress_enable_tls

  prometheus_prometheus_domain     = var.prometheus_prometheus_domain
  prometheus_grafana_storage_class = var.prometheus_persistence_storage_class_name
  prometheus_persistence_size      = var.prometheus_persistence_size

  prometheus_alertmanager_slack_channel     = var.prometheus_alertmanager_slack_channel
  prometheus_alertmanager_slack_credentials = var.prometheus_alertmanager_slack_credentials

  prometheus_minio_job_bearer_token          = var.prometheus_minio_job_bearer_token
  prometheus_minio_job_node_bearer_token     = var.prometheus_minio_job_node_bearer_token
  prometheus_minio_job_bucket_bearer_token   = var.prometheus_minio_job_bucket_bearer_token
  prometheus_minio_job_resource_bearer_token = var.prometheus_minio_job_resource_bearer_token

  # Depends on the logging module, configure elastalert2
  elastalert2_elasticsearch_enabled  = var.logging_module_enable
  elastalert2_elasticsearch_host     = try(module.logging[0].elasticsearch_host, "")
  elastalert2_elasticsearch_port     = try(module.logging[0].elasticsearch_port, 9200)
  elastalert2_elasticsearch_username = try(module.logging[0].elasticsearch_username, "")
  elastalert2_elasticsearch_password = try(module.logging[0].elasticsearch_password, "")

  auth_oauth2_proxy_host = var.auth_oauth2_proxy_host
}


module "kubecost" {
  depends_on = [module.cert_manager_letsencrypt]
  source     = "./kubecost"

  nginx_frontend_basic_auth_base64 = var.nginx_frontend_basic_auth_base64
  kubecost_token                   = var.kubecost_token
  kubecost_ingress_host            = var.kubecost_ingress_host
  kubecost_ingress_enable_tls      = var.ingress_enable_tls
  kubecost_ingress_class_name      = var.kubecost_ingress_class_name
  auth_oauth2_proxy_host           = var.auth_oauth2_proxy_host
}

module "vpn" {
  depends_on = [module.kubernetes]
  source     = "./vpn"

  tailscale_enable           = var.tailscale_enable
  tailscale_auth_key         = var.tailscale_auth_key
  tailscale_advertise_routes = var.tailscale_advertise_routes
  tailscale_hostname         = var.tailscale_hostname

  wireguard_enable       = var.wireguard_enable
  wireguard_ingress_host = var.wireguard_ingress_host
  wireguard_timezone     = var.wireguard_timezone
  wireguard_port         = var.wireguard_port
  wireguard_peers        = var.wireguard_peers
}

module "argocd" {
  depends_on = [module.gitlab_platform, module.logging[0]]
  source     = "./argocd"

  prometheus_namespace             = module.monitoring.monitoring_namespace
  global_ingress_enable_tls        = var.ingress_enable_tls
  nginx_frontend_basic_auth_base64 = var.nginx_frontend_basic_auth_base64

  argocd_domain                 = var.argocd_domain
  argocd_ingress_class_name     = var.argocd_ingress_class_name
  argocd_ssh_known_hosts_base64 = var.argocd_ssh_known_hosts_base64
  argocd_config_repositories    = jsondecode(var.argocd_config_repositories_json_encoded)
  argocd_rbac_policy_default    = var.argocd_rbac_policy_default
  argocd_rbac_policy_csv        = var.argocd_rbac_policy_csv

  auth_oauth2_proxy_host = var.auth_oauth2_proxy_host

  argocd_auth0_domain        = var.auth_auth0_domain
  argocd_auth0_client_id     = var.auth_auth0_client_id
  argocd_auth0_client_secret = var.auth_auth0_client_secret
}


module "datadog" {
  count      = var.datadog_enable ? 1 : 0
  depends_on = [module.cert_manager_letsencrypt]
  source     = "./datadog"

  datadog_cluster_name = var.datadog_cluster_name
  datadog_app_key      = var.datadog_app_key
  datadog_api_key      = var.datadog_api_key
}
