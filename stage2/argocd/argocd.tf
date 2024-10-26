# secret


resource "helm_release" "argo_cd" {
  depends_on = [
    kubernetes_namespace.argocd
  ]

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.6.12"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  wait       = true

  values = [
    templatefile("${path.module}/templates/argocd-values.tftpl", {
      prometheus_namespace             = var.prometheus_namespace
      global_ingress_enable_tls        = var.global_ingress_enable_tls
      nginx_frontend_basic_auth_base64 = var.nginx_frontend_basic_auth_base64
      argocd_domain                    = var.argocd_domain
      argocd_ingress_class_name        = var.argocd_ingress_class_name
      argocd_ssh_known_hosts_base64    = var.argocd_ssh_known_hosts_base64
    })
  ]
}
data "kubernetes_secret" "argocd_initial_admin_secret" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  depends_on = [
    helm_release.argo_cd
  ]
}
