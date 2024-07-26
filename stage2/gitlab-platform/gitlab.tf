resource "kubernetes_namespace" "gitlab" {
  metadata {
    name = "gitlab"
  }
}


resource "helm_release" "gitlab" {
  depends_on = [
    kubernetes_namespace.gitlab,
    kubernetes_secret.initial_root_password,
    kubernetes_secret.redis_password,
    kubernetes_secret.rails_secret,
    kubernetes_secret.postgresql_password,
    kubernetes_secret.runner_registration_token,
    kubernetes_secret.gitlab_runner_s3_access,
    kubernetes_secret.gitlab_shell_secret,
    kubernetes_secret.gitaly_secret,
    kubernetes_secret.gitlab_shell_host_keys,
    kubernetes_secret.gitlab_object_store_connection,
    kubernetes_secret.gitlab_registry_httpsecret,
    kubernetes_secret.gitlab_registry_storage_secret,
  ]

  name       = "gitlab"
  repository = "https://charts.gitlab.io/"
  chart      = "gitlab"
  version    = "8.1.2"
  namespace  = kubernetes_namespace.gitlab.metadata[0].name
  timeout    = 300

  values = [
    templatefile(
      "${path.module}/templates/gitlab-values.tftpl",
      {
        global_hosts_domain      = var.gitlab_global_hosts_domain
        global_hosts_host_suffix = var.gitlab_global_hosts_host_suffix
        global_hosts_https       = var.gitlab_global_hosts_https
        global_hosts_external_ip = var.gitlab_global_hosts_external_ip

        global_ingress_provider = var.gitlab_global_ingress_provider
        global_ingress_class    = var.gitlab_global_ingress_class

        global_initial_root_password_secret     = kubernetes_secret.initial_root_password.metadata[0].name
        global_redis_secret                     = kubernetes_secret.redis_password.metadata[0].name
        global_postgresql_password_secret       = kubernetes_secret.postgresql_password.metadata[0].name
        global_rails_secrets                    = kubernetes_secret.rails_secret.metadata[0].name
        global_runner_registration_token_secret = kubernetes_secret.runner_registration_token.metadata[0].name
        global_shell_auth_token_secret          = kubernetes_secret.gitlab_shell_secret.metadata[0].name
        global_shell_host_keys_secret           = kubernetes_secret.gitlab_shell_host_keys.metadata[0].name
        global_gitaly_auth_token_secret         = kubernetes_secret.gitaly_secret.metadata[0].name

        object_store_connection_secret = kubernetes_secret.gitlab_object_store_connection.metadata[0].name
        registry_http_secret           = kubernetes_secret.gitlab_registry_httpsecret.metadata[0].name
        registry_storage_secret        = kubernetes_secret.gitlab_registry_storage_secret.metadata[0].name
        runner_s3_access_secret        = kubernetes_secret.gitlab_runner_s3_access.metadata[0].name
        toolbox_s3cmd_secret           = kubernetes_secret.gitlab_toolbox_s3cmd.metadata[0].name

        certmanager_issuer_email = var.gitlab_certmanager_issuer_email

        time_zone = var.gitlab_time_zone

        minio_endpoint = var.gitlab_minio_endpoint

        persistence_storage_class_name = var.gitlab_persistence_storage_class_name
      }
    ),
  ]
}
