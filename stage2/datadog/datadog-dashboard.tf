# resource "kubectl_manifest" "datadog_dashboard" {
#   depends_on = [kubernetes_namespace.datadog]

#   yaml_body = templatefile(
#     "${path.module}/templates/datadog-dashboard.tftpl",
#     {
#       namespace = kubernetes_namespace.datadog.metadata[0].name
#       name      = "example-dashboard"
#     }
#   )
# }
