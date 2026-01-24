resource "kubernetes_namespace_v1" "minio_operator" {
  metadata {
    name = "minio-operator"
  }
}

resource "kubernetes_namespace_v1" "minio_tenant" {
  metadata {
    name = "minio-tenant"
  }
}

resource "kubernetes_secret_v1" "frontend_basic_auth" {
  metadata {
    name      = "frontend-basic-auth"
    namespace = kubernetes_namespace_v1.minio_tenant.metadata[0].name
  }

  data = {
    auth = base64decode(var.nginx_frontend_basic_auth_base64)
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}


resource "kubernetes_config_map_v1" "minio_custom_headers" {
  depends_on = [
    kubernetes_namespace_v1.minio_tenant
  ]

  metadata {
    name      = "minio-custom-headers"
    namespace = "nginx"
  }

  data = {
    "X-Real-IP"         = "$remote_addr"
    "X-Forwarded-For"   = "$proxy_add_x_forwarded_for"
    "X-Forwarded-Proto" = "$scheme"
  }
}

resource "helm_release" "minio_operator" {
  depends_on = [
    kubernetes_namespace_v1.minio_operator,
    # kubectl_manifest.sts_tls_certificate
  ]

  name       = "minio-operator"
  repository = "https://operator.min.io"
  chart      = "operator"
  version    = "7.1.1"
  namespace  = kubernetes_namespace_v1.minio_operator.metadata[0].name
  timeout    = 300
  wait       = true

  values = [
    templatefile(
      "${path.module}/minio-operator-values.tftpl",
      {
      }
    ),
  ]
}

resource "random_password" "minio_tenant_root_password" {
  length  = 16
  special = false
}

resource "kubernetes_secret_v1" "minio_tenant_env" {
  depends_on = [
    kubernetes_namespace_v1.minio_tenant,
    random_password.minio_tenant_root_password
  ]

  metadata {
    name      = "minio-env-configuration"
    namespace = kubernetes_namespace_v1.minio_tenant.metadata[0].name
  }

  data = {
    "config.env" = <<EOH
      export MINIO_ROOT_USER=${var.minio_tenant_root_user}
      export MINIO_ROOT_PASSWORD=${random_password.minio_tenant_root_password.result}
      EOH
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}
resource "random_password" "minio_console_passphrase" {
  length  = 16
  special = true
}

resource "random_password" "minio_console_salt" {
  length  = 16
  special = true
}

resource "random_password" "minio_tenant_user_secret_key" {
  length  = 16
  special = false
}


resource "kubernetes_secret_v1" "minio_tenant_user" {
  depends_on = [
    kubernetes_namespace_v1.minio_tenant
  ]

  metadata {
    name      = var.minio_tenant_user_access_key
    namespace = kubernetes_namespace_v1.minio_tenant.metadata[0].name
  }

  data = {
    CONSOLE_ACCESS_KEY = var.minio_tenant_user_access_key
    CONSOLE_SECRET_KEY = random_password.minio_tenant_user_secret_key.result
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "helm_release" "minio_tenant" {
  depends_on = [
    helm_release.minio_operator,
    kubernetes_namespace_v1.minio_tenant,
    kubernetes_secret_v1.minio_tenant_env,
    kubernetes_secret_v1.minio_tenant_user,
    kubernetes_secret_v1.frontend_basic_auth,
    kubernetes_config_map_v1.minio_custom_headers
    # kubectl_manifest.minio_tenant_certmanager_cert
  ]

  name       = "minio-tenant"
  repository = "https://operator.min.io"
  chart      = "tenant"
  version    = "7.1.1"
  namespace  = kubernetes_namespace_v1.minio_tenant.metadata[0].name
  timeout    = 300
  wait       = true

  values = [
    templatefile(
      "${path.module}/minio-tenant-values.tftpl",
      {
        frontend_basic_auth_secret_name = kubernetes_secret_v1.frontend_basic_auth.metadata[0].name
        tenant_configuration_name       = kubernetes_secret_v1.minio_tenant_env.metadata[0].name
        tenant_pools_servers            = var.minio_tenant_pools_servers
        tenant_pools_size               = var.minio_tenant_pools_size
        tenant_pools_storage_class_name = var.minio_tenant_pools_storage_class_name
        tenant_default_buckets          = var.minio_tenant_default_buckets
        tenant_user_access_key          = var.minio_tenant_user_access_key
        tenant_ingress_class_name       = var.minio_tenant_ingress_class_name
        tenant_ingress_api_host         = var.minio_tenant_ingress_api_host
        tenant_ingress_console_host     = var.minio_tenant_ingress_console_host
        tenant_ingress_enable_tls       = var.minio_tenant_ingress_enable_tls
        auth_oauth2_proxy_host          = var.auth_oauth2_proxy_host
      }
    ),
  ]
}
