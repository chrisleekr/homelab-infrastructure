# https://docs.gitlab.com/charts/installation/secrets.html#initial-root-password
resource "random_password" "initial_root_password" {
  length  = 64
  special = false
}

resource "kubernetes_secret" "initial_root_password" {
  depends_on = [
    kubernetes_namespace.gitlab,
    random_password.initial_root_password
  ]
  metadata {
    name      = "initial-root-password"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    password = random_password.initial_root_password.result
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

# https://docs.gitlab.com/charts/installation/secrets.html#redis-password
resource "random_password" "redis_password" {
  length  = 64
  special = false
}

resource "kubernetes_secret" "redis_password" {
  depends_on = [
    kubernetes_namespace.gitlab,
    random_password.redis_password
  ]
  metadata {
    name      = "redis-password"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    password = random_password.redis_password.result
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

# https://docs.gitlab.com/charts/installation/secrets.html#postgresql-password
resource "random_password" "postgresql_password" {
  length  = 64
  special = false
}

resource "random_password" "postgresql_postgres_password" {
  length  = 64
  special = false
}

resource "kubernetes_secret" "postgresql_password" {
  depends_on = [
    kubernetes_namespace.gitlab,
    random_password.postgresql_password,
    random_password.postgresql_postgres_password
  ]
  metadata {
    name      = "postgresql-password"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "postgresql-password"          = random_password.postgresql_password.result
    "postgresql-postgres-password" = random_password.postgresql_postgres_password.result
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}


# https://docs.gitlab.com/charts/installation/secrets.html#gitlab-rails-secret
resource "random_password" "rails_secret_key_base" {
  length  = 128
  special = false
}

resource "random_password" "rails_otp_key_base" {
  length  = 128
  special = false
}

resource "random_password" "rails_db_key_base" {
  length  = 128
  special = false
}
resource "random_password" "encrypted_settings_key_base" {
  length  = 128
  special = false
}

resource "tls_private_key" "openid_connect_signing_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "kubernetes_secret" "rails_secret" {
  depends_on = [
    kubernetes_namespace.gitlab,
    random_password.rails_secret_key_base,
    random_password.rails_otp_key_base,
    random_password.rails_db_key_base,
  ]

  metadata {
    name      = "rails-secret"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "secrets.yml" = templatefile(
      "${path.module}/templates/rails-secrets.tftpl",
      {
        production_secret_key_base             = random_password.rails_secret_key_base.result,
        production_otp_key_base                = random_password.rails_otp_key_base.result,
        production_db_key_base                 = random_password.rails_db_key_base.result,
        production_encrypted_settings_key_base = random_password.encrypted_settings_key_base.result,
        production_openid_connect_signing_key  = indent(4, tls_private_key.openid_connect_signing_key.private_key_pem_pkcs8),
      }
    )
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

# https://docs.gitlab.com/charts/installation/secrets#gitlab-runner-secret
resource "random_password" "runner_registration_token" {
  length  = 64
  special = false
}

resource "kubernetes_secret" "runner_registration_token" {
  depends_on = [
    kubernetes_namespace.gitlab,
    random_password.runner_registration_token
  ]
  metadata {
    name      = "runner-registration-token"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "runner-registration-token" = random_password.runner_registration_token.result
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "kubernetes_secret" "gitlab_object_store_connection" {
  depends_on = [
    kubernetes_namespace.gitlab
  ]

  metadata {
    name      = "gitlab-object-store-connection"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "connection" = templatefile(
      "${path.module}/templates/object-store-connection.tftpl",
      {
        minio_host              = var.gitlab_minio_host
        minio_endpoint          = var.gitlab_minio_endpoint
        minio_access_key_id     = var.gitlab_minio_access_key
        minio_secret_access_key = var.gitlab_minio_secret_key
      }
    )
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "random_password" "gitlab_registry_httpsecret" {
  length  = 64
  special = false
}


resource "kubernetes_secret" "gitlab_registry_httpsecret" {
  depends_on = [kubernetes_namespace.gitlab]

  metadata {
    name      = "gitlab-registry-httpsecret"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "secret" = random_password.gitlab_registry_httpsecret.result
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "kubernetes_secret" "gitlab_registry_storage_secret" {
  depends_on = [
    kubernetes_namespace.gitlab
  ]

  metadata {
    name      = "gitlab-registry-storage"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "storage" = templatefile(
      "${path.module}/templates/registry-storage.tftpl",
      {
        minio_endpoint   = var.gitlab_minio_endpoint
        minio_access_key = var.gitlab_minio_access_key
        minio_secret_key = var.gitlab_minio_secret_key
      }
    )
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "kubernetes_secret" "gitlab_runner_s3_access" {
  depends_on = [
    kubernetes_namespace.gitlab
  ]

  metadata {
    name      = "gitlab-runner-s3-access"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "accesskey" = var.gitlab_minio_access_key
    "secretkey" = var.gitlab_minio_secret_key
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

# https://docs.gitlab.com/charts/installation/secrets.html#gitlab-shell-secret
resource "random_password" "gitlab_shell_secret" {
  length  = 64
  special = false
}

resource "kubernetes_secret" "gitlab_shell_secret" {
  depends_on = [random_password.gitlab_shell_secret]
  metadata {
    name      = "gitlab-shell-secret"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "secret" = random_password.gitlab_shell_secret.result
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

# https://docs.gitlab.com/charts/installation/secrets.html#gitaly-secret
resource "random_password" "gitaly_secret" {
  length  = 64
  special = false
}

resource "kubernetes_secret" "gitaly_secret" {
  depends_on = [
    kubernetes_namespace.gitlab,
    random_password.gitaly_secret
  ]
  metadata {
    name      = "gitaly-secret"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "token" = random_password.gitaly_secret.result
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

# https://docs.gitlab.com/charts/installation/secrets.html#ssh-host-keys
data "external" "generate_keys" {
  program = ["${path.module}/scripts/generate-host-keys.sh"]
}

resource "kubernetes_secret" "gitlab_shell_host_keys" {
  depends_on = [
    kubernetes_namespace.gitlab,
    data.external.generate_keys
  ]

  metadata {
    name      = "gitlab-shell-host-keys"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "ssh_host_rsa_key"         = base64decode(data.external.generate_keys.result["ssh_host_rsa_key"])
    "ssh_host_rsa_key.pub"     = base64decode(data.external.generate_keys.result["ssh_host_rsa_key.pub"])
    "ssh_host_dsa_key"         = base64decode(data.external.generate_keys.result["ssh_host_dsa_key"])
    "ssh_host_dsa_key.pub"     = base64decode(data.external.generate_keys.result["ssh_host_dsa_key.pub"])
    "ssh_host_ecdsa_key"       = base64decode(data.external.generate_keys.result["ssh_host_ecdsa_key"])
    "ssh_host_ecdsa_key.pub"   = base64decode(data.external.generate_keys.result["ssh_host_ecdsa_key.pub"])
    "ssh_host_ed25519_key"     = base64decode(data.external.generate_keys.result["ssh_host_ed25519_key"])
    "ssh_host_ed25519_key.pub" = base64decode(data.external.generate_keys.result["ssh_host_ed25519_key.pub"])
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}


resource "kubernetes_secret" "gitlab_toolbox_s3cmd" {
  depends_on = [
    kubernetes_namespace.gitlab
  ]

  metadata {
    name      = "toolbox-s3cmd-secret"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "config" = templatefile(
      "${path.module}/templates/toolbox-s3cmd.tftpl",
      {
        minio_host       = var.gitlab_minio_host
        minio_access_key = var.gitlab_minio_access_key
        minio_secret_key = var.gitlab_minio_secret_key
      }
    )
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}
