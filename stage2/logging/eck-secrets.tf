resource "kubernetes_secret" "frontend_basic_auth" {
  metadata {
    name      = "frontend-basic-auth"
    namespace = kubernetes_namespace.logging.metadata[0].name
  }

  data = {
    auth = base64decode(var.nginx_frontend_basic_auth_base64)
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}


resource "random_password" "elastic_password" {
  length  = 16
  special = false
}

resource "kubernetes_secret" "elasticsearch_secret" {
  depends_on = [
    kubernetes_namespace.logging,
    random_password.elastic_password,
    kubectl_manifest.max_map_count_setter
  ]

  metadata {
    name      = "elasticsearch-es-elastic-user"
    namespace = kubernetes_namespace.logging.metadata[0].name
  }

  data = {
    elastic = random_password.elastic_password.result
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "random_password" "kibana_encryption_key" {
  length  = 32
  special = false
}

resource "random_password" "kibana_encrypted_saved_objects_key" {
  length  = 32
  special = false
}

resource "random_password" "kibana_reporting_encryption_key" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "kibana_secret_settings" {
  depends_on = [
    kubernetes_namespace.logging,
    random_password.kibana_encryption_key,
    random_password.kibana_encrypted_saved_objects_key,
    random_password.kibana_reporting_encryption_key
  ]

  metadata {
    name      = "kibana-secret-settings"
    namespace = kubernetes_namespace.logging.metadata[0].name
  }

  data = {
    "xpack.security.encryptionKey"              = random_password.kibana_encryption_key.result
    "xpack.encryptedSavedObjects.encryptionKey" = random_password.kibana_encrypted_saved_objects_key.result
    "xpack.reporting.encryptionKey"             = random_password.kibana_reporting_encryption_key.result
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}
