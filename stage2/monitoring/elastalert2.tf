resource "kubernetes_secret" "elastalert2_credentials" {
  count = var.elastalert2_elasticsearch_enabled ? 1 : 0

  depends_on = [kubernetes_namespace.monitoring_namespace]

  metadata {
    name      = "elastalert2-credentials"
    namespace = kubernetes_namespace.monitoring_namespace.metadata[0].name
  }

  data = {
    username = var.elastalert2_elasticsearch_username
    password = var.elastalert2_elasticsearch_password
  }


  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "kubernetes_secret" "elastalert2_config" {
  count = var.elastalert2_elasticsearch_enabled ? 1 : 0

  depends_on = [kubernetes_namespace.monitoring_namespace]

  metadata {
    name      = "elastalert2-config-secret"
    namespace = kubernetes_namespace.monitoring_namespace.metadata[0].name
  }

  data = {
    elastalert_config = templatefile("${path.module}/elastalert2/elastalert2-config-secret.tftpl", {
      monitoring_namespace = kubernetes_namespace.monitoring_namespace.metadata[0].name
      elasticsearch_host   = var.elastalert2_elasticsearch_host
      elasticsearch_port   = var.elastalert2_elasticsearch_port
    })
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "helm_release" "elastalert2" {
  count = var.elastalert2_elasticsearch_enabled ? 1 : 0

  depends_on = [
    kubernetes_namespace.monitoring_namespace,
    kubernetes_secret.elastalert2_credentials[0],
    kubernetes_secret.elastalert2_config[0]
  ]

  name       = "elastalert2"
  repository = "https://jertel.github.io/elastalert2/"
  chart      = "elastalert2"
  version    = "2.24.0"
  namespace  = kubernetes_namespace.monitoring_namespace.metadata[0].name
  timeout    = 360
  wait       = true

  # Trigger release update if secret changes
  set = [
    {
      name  = "secretChecksum"
      value = md5(jsonencode(kubernetes_secret.elastalert2_config[0].data)) # Use a hash of the secret data
    }
  ]

  values = [
    templatefile("${path.module}/elastalert2/elastalert2-values.tftpl", {
      prometheus_namespace = kubernetes_namespace.monitoring_namespace.metadata[0].name

      secret_config_name = kubernetes_secret.elastalert2_config[0].metadata[0].name

      elasticsearch_host               = var.elastalert2_elasticsearch_host
      elasticsearch_port               = var.elastalert2_elasticsearch_port
      elasticsearch_credentials_secret = kubernetes_secret.elastalert2_credentials[0].metadata[0].name
    })
  ]
}
