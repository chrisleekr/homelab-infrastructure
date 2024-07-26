# # https://github.com/minio/operator/blob/master/docs/cert-manager.md#create-operator-ca-tls-secret
# Self-signed root certificate used in the minio
# resource "kubectl_manifest" "selfsigned_root" {
#   depends_on = [helm_release.cert_manager]

#   yaml_body = <<-EOF
#   apiVersion: cert-manager.io/v1
#   kind: ClusterIssuer
#   metadata:
#     name: selfsigned-root
#   spec:
#     selfSigned: {}
#   EOF
# }

# resource "kubectl_manifest" "operator_ca_tls_secret" {
#   depends_on = [kubernetes_namespace.minio_operator]

#   yaml_body = <<-EOF
#   apiVersion: cert-manager.io/v1
#   kind: Certificate
#   metadata:
#     name: minio-operator-ca-certificate
#     namespace: ${kubernetes_namespace.minio_operator.metadata[0].name}
#   spec:
#     isCA: true
#     commonName: operator
#     secretName: operator-ca-tls
#     duration: 70128h # 8y
#     privateKey:
#       algorithm: ECDSA
#       size: 256
#     issuerRef:
#       name: selfsigned-root
#       kind: ClusterIssuer
#       group: cert-manager.io
#   EOF
# }

# resource "kubectl_manifest" "operator_ca_issuer" {
#   depends_on = [kubectl_manifest.operator_ca_tls_secret]

#   yaml_body = <<-EOF
#   apiVersion: cert-manager.io/v1
#   kind: Issuer
#   metadata:
#     name: minio-operator-ca-issuer
#     namespace: ${kubernetes_namespace.minio_operator.metadata[0].name}
#   spec:
#     ca:
#       secretName: operator-ca-tls
#   EOF
# }


# resource "kubectl_manifest" "sts_tls_certificate" {
#   depends_on = [kubectl_manifest.operator_ca_issuer]

#   yaml_body = <<-EOF
#   apiVersion: cert-manager.io/v1
#   kind: Certificate
#   metadata:
#     name: sts-certmanager-cert
#     namespace: ${kubernetes_namespace.minio_operator.metadata[0].name}
#   spec:
#     dnsNames:
#       - sts
#       - sts.${kubernetes_namespace.minio_operator.metadata[0].name}.svc
#       - sts.${kubernetes_namespace.minio_operator.metadata[0].name}.svc.cluster.local
#     secretName: sts-tls
#     issuerRef:
#       name: ${kubernetes_namespace.minio_operator.metadata[0].name}-ca-issuer
#   EOF
# }



# resource "kubectl_manifest" "minio_tenant_ca_certificate" {
#   depends_on = [
#     kubectl_manifest.sts_tls_certificate,
#     kubernetes_namespace.minio_tenant
#   ]

#   yaml_body = <<-EOF
#   apiVersion: cert-manager.io/v1
#   kind: Certificate
#   metadata:
#     name: minio-tenant-ca-certificate
#     namespace: ${kubernetes_namespace.minio_tenant.metadata[0].name}
#   spec:
#     isCA: true
#     commonName: minio-tenant-ca
#     secretName: minio-tenant-ca-tls
#     duration: 70128h # 8y
#     privateKey:
#       algorithm: ECDSA
#       size: 256
#     issuerRef:
#       name: selfsigned-root
#       kind: ClusterIssuer
#       group: cert-manager.io
#   EOF
# }


# resource "kubectl_manifest" "minio_tenant_ca_issuer" {
#   depends_on = [kubectl_manifest.minio_tenant_ca_certificate]

#   yaml_body = <<-EOF
#   apiVersion: cert-manager.io/v1
#   kind: Issuer
#   metadata:
#     name: minio-tenant-ca-issuer
#     namespace: ${kubernetes_namespace.minio_tenant.metadata[0].name}
#   spec:
#     ca:
#       secretName: minio-tenant-ca-tls
#   EOF
# }

# resource "kubectl_manifest" "minio_tenant_certmanager_cert" {
#   depends_on = [kubectl_manifest.minio_tenant_ca_issuer]

#   yaml_body = <<-EOF
#   apiVersion: cert-manager.io/v1
#   kind: Certificate
#   metadata:
#     name: tenant-certmanager-cert
#     namespace: ${kubernetes_namespace.minio_tenant.metadata[0].name}
#   spec:
#     dnsNames:
#       - "minio.${kubernetes_namespace.minio_tenant.metadata[0].name}"
#       - "minio.${kubernetes_namespace.minio_tenant.metadata[0].name}.svc"
#       - 'minio.${kubernetes_namespace.minio_tenant.metadata[0].name}.svc.cluster.local'
#       - '*.minio.${kubernetes_namespace.minio_tenant.metadata[0].name}.svc.cluster.local'
#       - '*.minio-tenant-hl.${kubernetes_namespace.minio_tenant.metadata[0].name}.svc.cluster.local'
#       - '*.minio-tenant.minio.${kubernetes_namespace.minio_tenant.metadata[0].name}.svc.cluster.local'
#     secretName: minio-tenant-tls
#     issuerRef:
#       name: minio-tenant-ca-issuer
#   EOF
# }


# data "kubernetes_secret" "minio_tenant_ca_tls" {
#   depends_on = [kubectl_manifest.minio_tenant_certmanager_cert]
#   metadata {
#     name      = "minio-tenant-ca-tls"
#     namespace = kubernetes_namespace.minio_tenant.metadata[0].name
#   }

# lifecycle {
#   ignore_changes = [metadata[0].labels]
# }
# }

# resource "local_file" "minio_tenant_ca_crt" {
#   depends_on = [data.kubernetes_secret.minio_tenant_ca_tls]

#   content  = data.kubernetes_secret.minio_tenant_ca_tls.data["ca.crt"]
#   filename = "${path.module}/minio-tenant-ca.crt"
# }

# resource "kubernetes_secret" "operator_ca_tls_minio_tenant" {
#   depends_on = [
#     kubernetes_namespace.minio_operator,
#     local_file.minio_tenant_ca_crt
#   ]

#   metadata {
#     name      = "operator-ca-tls-minio-tenant"
#     namespace = kubernetes_namespace.minio_operator.metadata[0].name
#   }

#   data = {
#     "ca.crt" = local_file.minio_tenant_ca_crt.content
#   }

# lifecycle {
#   ignore_changes = [metadata[0].labels]
# }
# }
