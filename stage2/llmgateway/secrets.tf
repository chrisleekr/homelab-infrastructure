# Kubernetes secret for LLM Gateway authentication
# AUTH_SECRET is used for session management and security

resource "kubernetes_secret" "llmgateway_auth" {
  count = var.llmgateway_enable ? 1 : 0

  metadata {
    name      = "llmgateway-auth"
    namespace = kubernetes_namespace.llmgateway[0].metadata[0].name
  }

  data = {
    AUTH_SECRET = var.llmgateway_auth_secret
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]

    # Validate auth_secret is provided when module is enabled
    # Fails at plan time rather than discovering issues post-deployment
    precondition {
      condition     = length(var.llmgateway_auth_secret) >= 32
      error_message = "llmgateway_auth_secret must be at least 32 characters when llmgateway_enable is true. Generate with: openssl rand -hex 32"
    }
  }
}
