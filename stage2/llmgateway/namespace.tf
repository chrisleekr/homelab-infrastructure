# Kubernetes namespace for LLM Gateway resources
# Only created when module is enabled to avoid orphaned namespaces

resource "kubernetes_namespace" "llmgateway" {
  count = var.llmgateway_enable ? 1 : 0

  metadata {
    name = "llmgateway"
  }
}
