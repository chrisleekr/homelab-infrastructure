# LLM Gateway Storage Resources
# Persistent storage for embedded PostgreSQL database

# Persistent Volume Claim for PostgreSQL data
resource "kubernetes_persistent_volume_claim_v1" "llmgateway_data" {
  count = var.llmgateway_enable ? 1 : 0

  metadata {
    name      = "llmgateway-data"
    namespace = kubernetes_namespace.llmgateway[0].metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.llmgateway_storage_class_name

    resources {
      requests = {
        storage = var.llmgateway_storage_size
      }
    }
  }
}
