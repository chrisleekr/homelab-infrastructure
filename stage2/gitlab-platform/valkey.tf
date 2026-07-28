# Valkey replaces the bundled Redis chart, removed in GitLab chart 10.0. It lives in this
# module rather than its own so it shares the GitLab namespace and lifecycle.

resource "random_password" "valkey_password" {
  length  = 64
  special = false
}

resource "kubernetes_secret_v1" "valkey_password" {
  depends_on = [
    kubernetes_namespace_v1.gitlab,
    random_password.valkey_password
  ]

  metadata {
    name      = "valkey-password"
    namespace = kubernetes_namespace_v1.gitlab.metadata[0].name
  }

  # Key name must equal the ACL username. See templates/valkey-values.tftpl.
  data = {
    default = random_password.valkey_password.result
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "helm_release" "valkey" {
  depends_on = [
    kubernetes_secret_v1.valkey_password
  ]

  # The release name must contain "valkey" so the chart fullname collapses to
  # "gitlab-valkey", which is the Service name GitLab is pointed at.
  name       = local.valkey_release_name
  repository = "https://valkey.io/valkey-helm/"
  chart      = "valkey"
  version    = "0.11.0"
  namespace  = kubernetes_namespace_v1.gitlab.metadata[0].name
  timeout    = 300
  wait       = true

  values = [
    templatefile(
      "${path.module}/templates/valkey-values.tftpl",
      {
        valkey_password_secret         = kubernetes_secret_v1.valkey_password.metadata[0].name
        valkey_persistence_size        = var.gitlab_valkey_persistence_size
        persistence_storage_class_name = var.gitlab_persistence_storage_class_name
      }
    )
  ]
}
