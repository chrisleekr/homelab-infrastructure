resource "kubernetes_namespace" "nginx" {
  metadata {
    name = "nginx"
  }
}

resource "helm_release" "nginx" {
  depends_on = [
    kubernetes_namespace.nginx,
  ]

  name       = "nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.11.0"
  namespace  = "nginx"
  wait       = true

  values = [
    templatefile(
      "${path.module}/templates/nginx-values.tftpl",
      {
        nginx_service_loadbalancer_ip = var.nginx_service_loadbalancer_ip
      }
    )
  ]
}
