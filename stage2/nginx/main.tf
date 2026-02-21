resource "kubernetes_namespace_v1" "nginx" {
  metadata {
    name = "nginx"
  }

  # Required module: guards against accidental destruction. To intentionally destroy, set prevent_destroy = false, apply, then revert.
  lifecycle {
    prevent_destroy = true
  }
}

resource "helm_release" "nginx" {
  depends_on = [
    kubernetes_namespace_v1.nginx,
  ]

  name       = "nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.14.1"
  namespace  = "nginx"
  timeout    = 300
  wait       = true

  values = [
    templatefile(
      "${path.module}/templates/nginx-values.tftpl",
      {
        nginx_service_loadbalancer_ip = var.nginx_service_loadbalancer_ip
        nginx_client_max_body_size    = var.nginx_client_max_body_size
        nginx_client_body_buffer_size = var.nginx_client_body_buffer_size

        wireguard_port = var.wireguard_port
      }
    )
  ]
}
