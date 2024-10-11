# Note: I failed to configure fluentd to parse containerd logs.

# Create secret for elasticsearch_user and elasticsearch_password
# resource "kubernetes_secret" "elasticsearch_credentials" {
#   metadata {
#     name      = "elasticsearch-credentials"
#     namespace = kubernetes_namespace.logging.metadata[0].name
#   }

#   data = {
#     username = var.elasticsearch_user
#     password = var.elasticsearch_password
#   }
# }

# Note: This is not working because cannot configure regexp to parse containerd logs.
# resource "helm_release" "fluent_operator" {
#   depends_on = [
#     kubernetes_namespace.logging,
#     kubernetes_secret.elasticsearch_credentials
#   ]

#   name       = "fluent-operator"
#   repository = "https://fluent.github.io/helm-charts"
#   chart      = "fluent-operator"
#   version    = "3.2.0"
#   namespace  = kubernetes_namespace.logging.metadata[0].name
#   timeout    = 300
#   wait       = true

#   values = [
#     templatefile(
#       "${path.module}/templates/fluent/fluent-operator-values.tftpl",
#       {
#         namespace = kubernetes_namespace.logging.metadata[0].name
#       }
#     )
#   ]
# }

# Note: This is not working because fluentd does not support replace dots in the filter.
# Causing this error:
#     400 - Rejected by Elasticsearch [error type]: document_parsing_exception [reason]: '[1:1037] object mapping for [kubernetes.labels.app] tried to parse field [app] as object, but found a concrete value'
# resource "helm_release" "fluentd" {
#   depends_on = [
#     kubernetes_namespace.logging,
#     kubernetes_secret.elasticsearch_credentials
#   ]

#   name       = "fluentd"
#   repository = "https://fluent.github.io/helm-charts"
#   chart      = "fluentd"
#   version    = "0.5.2"
#   namespace  = kubernetes_namespace.logging.metadata[0].name
#   timeout    = 300
#   wait       = true

#   values = [
#     templatefile(
#       "${path.module}/templates/fluent/fluentd-values.tftpl",
#       {
#         namespace = kubernetes_namespace.logging.metadata[0].name
#       }
#     )
#   ]
# }
