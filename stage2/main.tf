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

  gitlab_minio_host     = var.minio_tenant_ingress_api_host
  gitlab_minio_endpoint = var.ingress_enable_tls ? "https://${var.minio_tenant_ingress_api_host}" : "http://${var.minio_tenant_ingress_api_host}"


  gitlab_minio_access_key = var.minio_tenant_user_access_key
  gitlab_minio_secret_key = module.minio_object_storage.minio_tenant_user_secret_key

  gitlab_persistence_storage_class_name        = var.gitlab_persistence_storage_class_name
  gitlab_toolbox_backups_cron_persistence_size = var.gitlab_toolbox_backups_cron_persistence_size
  gitlab_toolbox_persistence_size              = var.gitlab_toolbox_persistence_size

  gitlab_postgresql_primary_persistence_size = var.gitlab_postgresql_primary_persistence_size
  gitlab_redis_master_persistence_size       = var.gitlab_redis_master_persistence_size
  gitlab_gitlay_persistence_size             = var.gitlab_gitlay_persistence_size
}


module "prometheus_stack" {
  depends_on = [module.cert_manager_letsencrypt]
  source     = "./prometheus-stack"

  nginx_frontend_basic_auth_base64 = var.nginx_frontend_basic_auth_base64
  prometheus_alertmanager_domain   = var.prometheus_alertmanager_domain
  prometheus_grafana_domain        = var.prometheus_grafana_domain
  prometheus_ingress_class_name    = var.prometheus_ingress_class_name
  prometheus_ingress_enable_tls    = var.ingress_enable_tls

  prometheus_prometheus_domain     = var.prometheus_prometheus_domain
  prometehus_grafana_storage_class = var.prometheus_persistence_storage_class_name
  prometheus_persistence_size      = var.prometheus_persistence_size

  prometheus_alertmanager_slack_channel     = var.prometheus_alertmanager_slack_channel
  prometheus_alertmanager_slack_credentials = var.prometheus_alertmanager_slack_credentials

  prometheus_minio_job_bearer_token          = var.prometheus_minio_job_bearer_token
  prometheus_minio_job_node_bearer_token     = var.prometheus_minio_job_node_bearer_token
  prometheus_minio_job_bucket_bearer_token   = var.prometheus_minio_job_bucket_bearer_token
  prometheus_minio_job_resource_bearer_token = var.prometheus_minio_job_resource_bearer_token
}

module "logging" {
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

  elasticsearch_user     = "elastic"
  elasticsearch_password = module.logging.elasticsearch_password
}
