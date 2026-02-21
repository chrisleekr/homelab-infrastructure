resource "kubernetes_namespace_v1" "longhorn" {
  metadata {
    name = "longhorn-system"
  }

  # Required module: guards against accidental destruction. To intentionally destroy, set prevent_destroy = false, apply, then revert.
  lifecycle {
    prevent_destroy = true
  }
}


resource "kubernetes_secret_v1" "frontend_basic_auth" {
  metadata {
    name      = "frontend-basic-auth"
    namespace = kubernetes_namespace_v1.longhorn.metadata[0].name
  }

  data = {
    auth = base64decode(var.nginx_frontend_basic_auth_base64)
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "helm_release" "longhorn" {
  depends_on = [kubernetes_namespace_v1.longhorn]

  name       = "longhorn"
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  namespace  = kubernetes_namespace_v1.longhorn.metadata[0].name
  version    = "1.10.1"
  wait       = true
  timeout    = 300

  values = [
    templatefile(
      "${path.module}/templates/longhorn-values.tftpl",
      {
        auth_oauth2_proxy_host                      = var.auth_oauth2_proxy_host
        frontend_basic_auth_secret_name             = kubernetes_secret_v1.frontend_basic_auth.metadata[0].name
        longhorn_default_settings_default_data_path = var.longhorn_default_settings_default_data_path
        longhorn_ingress_class_name                 = var.longhorn_ingress_class_name
        longhorn_ingress_host                       = var.longhorn_ingress_host
        longhorn_ingress_enable_tls                 = var.longhorn_ingress_enable_tls
      }
    ),
  ]
}

resource "null_resource" "remove_default" {
  depends_on = [helm_release.longhorn]
  provisioner "local-exec" {
    command = <<EOT
if kubectl get storageclass local-path; then
  kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
fi
EOT
  }
}
