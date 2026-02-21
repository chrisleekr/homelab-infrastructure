resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = "cert-manager"
  }

  # Required module: guards against accidental destruction. To intentionally destroy, set prevent_destroy = false, apply, then revert.
  lifecycle {
    prevent_destroy = true
  }
}
resource "helm_release" "cert_manager" {
  depends_on = [
    kubernetes_namespace_v1.cert_manager
  ]

  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.19.2"
  namespace  = kubernetes_namespace_v1.cert_manager.metadata[0].name
  timeout    = 300
  wait       = true

  values = [
    templatefile(
      "${path.module}/cert-manager-values.tftpl",
      {
        host_alias_ip        = var.cert_manager_host_alias_ip
        host_alias_hostnames = var.cert_manager_host_alias_hostnames
      }
    )
  ]
}

resource "kubectl_manifest" "cluster_issuer" {
  depends_on = [
    helm_release.cert_manager
  ]

  yaml_body = <<-EOF
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: letsencrypt-prod
  spec:
    acme:
      email: ${var.cert_manager_acme_email}
      server: https://acme-v02.api.letsencrypt.org/directory
      privateKeySecretRef:
        name: letsencrypt-prod
      solvers:
      - http01:
          ingress:
            ingressClassName: ${var.cert_manager_ingress_class}
  EOF

}
