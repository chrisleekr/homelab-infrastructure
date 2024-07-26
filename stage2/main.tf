module "kubernetes" {
  source = "./kubernetes"

  kubernetes_override_domains = var.kubernetes_override_domains
  kubernetes_override_ip      = var.kubernetes_override_ip
}

module "nginx" {
  source                        = "./nginx"
  nginx_service_loadbalancer_ip = var.nginx_service_loadbalancer_ip
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
}

module "gitlab_platform" {
  depends_on = [module.minio_object_storage]
  source     = "./gitlab-platform"

  gitlab_global_hosts_domain      = var.gitlab_global_hosts_domain
  gitlab_global_hosts_host_suffix = var.gitlab_global_hosts_host_suffix
  gitlab_global_hosts_external_ip = var.gitlab_global_hosts_external_ip
  gitlab_global_ingress_provider  = var.gitlab_global_ingress_provider
  gitlab_global_ingress_class     = var.gitlab_global_ingress_class

  gitlab_certmanager_issuer_email = var.gitlab_certmanager_issuer_email

  gitlab_minio_host       = var.minio_tenant_ingress_api_host
  gitlab_minio_endpoint   = "https://${var.minio_tenant_ingress_api_host}"
  gitlab_minio_access_key = var.minio_tenant_user_access_key
  gitlab_minio_secret_key = module.minio_object_storage.minio_tenant_user_secret_key

  gitlab_persistence_storage_class_name = var.gitlab_persistence_storage_class_name
}


module "prometheus_stack" {
  depends_on = [module.gitlab_platform]
  source     = "./prometheus-stack"

  nginx_frontend_basic_auth_base64 = var.nginx_frontend_basic_auth_base64
  prometheus_alertmanager_domain   = var.prometheus_alertmanager_domain
  prometheus_grafana_domain        = var.prometheus_grafana_domain
  prometheus_ingress_class_name    = var.prometheus_ingress_class_name
  prometheus_prometheus_domain     = var.prometheus_prometheus_domain
  prometehus_grafana_storage_class = var.prometheus_persistence_storage_class_name

}
