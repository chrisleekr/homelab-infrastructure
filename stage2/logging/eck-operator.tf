resource "helm_release" "eck_operator" {
  depends_on = [
    kubernetes_namespace.logging,
  ]

  name       = "elastic-operator"
  repository = "https://helm.elastic.co"
  chart      = "eck-operator"
  version    = "2.16.1"
  namespace  = kubernetes_namespace.logging.metadata[0].name
  timeout    = 300
  wait       = true

  values = []
}

# Wait until eck-operator is ready
resource "null_resource" "eck_operator_ready" {
  triggers = {
    eck_operator_ready = helm_release.eck_operator.metadata.name
  }

  provisioner "local-exec" {
    command = "kubectl wait --for=condition=ready --timeout=300s --namespace ${kubernetes_namespace.logging.metadata[0].name} pod -l app.kubernetes.io/name=elastic-operator"
  }
}
