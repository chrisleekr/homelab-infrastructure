resource "kubernetes_namespace" "elastic_system" {
  metadata {
    name = "elastic-system"
  }
}

# locals {
#   eck_crds = [
#     "kubectl apply --server-side -f https://download.elastic.co/downloads/eck/2.14.0/crds.yaml"
#   ]
# }

# resource "null_resource" "eck_crd" {
#   triggers = {
#     eck_crd_urls = join(",", local.eck_crds)
#     # always_run          = "${timestamp()}"
#   }

#   # Should apply the CRDs in order; otherwise, timeout errors may occur.
#   provisioner "local-exec" {
#     command = local.eck_crds[0]
#   }
# }


resource "helm_release" "eck_operator" {
  depends_on = [
    kubernetes_namespace.elastic_system,
  ]

  name       = "elastic-operator"
  repository = "https://helm.elastic.co"
  chart      = "eck-operator"
  version    = "2.14.0"
  namespace  = kubernetes_namespace.elastic_system.metadata[0].name
  timeout    = 300

  values = []
}

# Wait until eck-operator is ready
resource "null_resource" "eck_operator_ready" {
  triggers = {
    eck_operator_ready = helm_release.eck_operator.metadata[0].name
  }

  provisioner "local-exec" {
    command = "kubectl wait --for=condition=ready --timeout=300s --namespace ${kubernetes_namespace.elastic_system.metadata[0].name} pod -l app.kubernetes.io/name=elastic-operator"
  }
}
