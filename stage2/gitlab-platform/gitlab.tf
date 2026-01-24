resource "kubernetes_namespace_v1" "gitlab" {
  metadata {
    name = "gitlab"
  }
}


resource "helm_release" "gitlab" {
  depends_on = [
    kubernetes_namespace_v1.gitlab,
    kubernetes_secret_v1.initial_root_password,
    kubernetes_secret_v1.redis_password,
    kubernetes_secret_v1.rails_secret,
    kubernetes_secret_v1.postgresql_password,
    kubernetes_secret_v1.gitlab_runner_s3_access,
    kubernetes_secret_v1.gitlab_shell_secret,
    kubernetes_secret_v1.gitaly_secret,
    kubernetes_secret_v1.gitlab_shell_host_keys,
    kubernetes_secret_v1.gitlab_object_store_connection,
    kubernetes_secret_v1.gitlab_registry_httpsecret,
    kubernetes_secret_v1.gitlab_registry_storage_secret,
    kubernetes_secret_v1.gitlab_registry_database_password
  ]

  name       = "gitlab"
  repository = "https://charts.gitlab.io/"
  chart      = "gitlab"
  version    = "9.8.2"
  namespace  = kubernetes_namespace_v1.gitlab.metadata[0].name
  timeout    = 600 # 10 minutes
  wait       = true

  values = [
    templatefile(
      "${path.module}/templates/gitlab-values.tftpl",
      {
        # Workaround - https://gitlab.com/groups/gitlab-org/-/epics/10938
        platform_image_tag = var.host_machine_architecture == "arm64" ? "16-5-arm64" : "master"

        global_hosts_domain      = var.gitlab_global_hosts_domain
        global_hosts_host_suffix = var.gitlab_global_hosts_host_suffix
        global_hosts_https       = var.gitlab_global_hosts_https
        global_hosts_external_ip = var.gitlab_global_hosts_external_ip

        global_ingress_provider   = var.gitlab_global_ingress_provider
        global_ingress_class      = var.gitlab_global_ingress_class
        global_ingress_enable_tls = var.gitlab_global_ingress_enable_tls

        global_initial_root_password_secret = kubernetes_secret_v1.initial_root_password.metadata[0].name
        global_redis_secret                 = kubernetes_secret_v1.redis_password.metadata[0].name
        global_postgresql_password_secret   = kubernetes_secret_v1.postgresql_password.metadata[0].name
        global_rails_secrets                = kubernetes_secret_v1.rails_secret.metadata[0].name

        global_shell_auth_token_secret  = kubernetes_secret_v1.gitlab_shell_secret.metadata[0].name
        global_shell_host_keys_secret   = kubernetes_secret_v1.gitlab_shell_host_keys.metadata[0].name
        global_gitaly_auth_token_secret = kubernetes_secret_v1.gitaly_secret.metadata[0].name

        object_store_connection_secret = kubernetes_secret_v1.gitlab_object_store_connection.metadata[0].name
        registry_http_secret           = kubernetes_secret_v1.gitlab_registry_httpsecret.metadata[0].name
        registry_storage_secret        = kubernetes_secret_v1.gitlab_registry_storage_secret.metadata[0].name
        registry_database_password     = kubernetes_secret_v1.gitlab_registry_database_password.metadata[0].name

        runner_s3_access_secret = kubernetes_secret_v1.gitlab_runner_s3_access.metadata[0].name
        toolbox_s3cmd_secret    = kubernetes_secret_v1.gitlab_toolbox_s3cmd.metadata[0].name

        gitlab_runner_gitlab_url           = var.gitlab_global_hosts_https ? "https://gitlab.${var.gitlab_global_hosts_domain}" : "http://gitlab.${var.gitlab_global_hosts_domain}"
        gitlab_runner_authentication_token = var.gitlab_runner_authentication_token
        gitlab_runner_token_secret         = kubernetes_secret_v1.runner_token.metadata[0].name

        certmanager_issuer_email = var.gitlab_certmanager_issuer_email

        time_zone = var.gitlab_time_zone

        minio_host       = var.gitlab_minio_host
        minio_access_key = var.gitlab_minio_access_key
        minio_secret_key = var.gitlab_minio_secret_key
        # minio_endpoint = var.gitlab_minio_endpoint

        persistence_storage_class_name = var.gitlab_persistence_storage_class_name

        toolbox_backups_cron_persistence_size = var.gitlab_toolbox_backups_cron_persistence_size
        toolbox_persistence_size              = var.gitlab_toolbox_persistence_size

        postgresql_primary_persistence_size = var.gitlab_postgresql_primary_persistence_size

        redis_master_persistence_size = var.gitlab_redis_master_persistence_size
        gitlay_persistence_size       = var.gitlab_gitlay_persistence_size

        # Auth0 configuration
        auth0_provider_secret = kubernetes_secret_v1.gitlab_auth0_provider.metadata[0].name
      }
    ),
  ]
}
