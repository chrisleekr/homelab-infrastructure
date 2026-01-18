# Output values for LLM Gateway module

output "llmgateway_namespace" {
  description = "Kubernetes namespace where LLM Gateway is deployed"
  value       = var.llmgateway_enable ? kubernetes_namespace.llmgateway[0].metadata[0].name : null
}

output "llmgateway_service_name" {
  description = "Name of the LLM Gateway Kubernetes service"
  value       = var.llmgateway_enable ? kubernetes_service_v1.llmgateway[0].metadata[0].name : null
}

output "llmgateway_url" {
  description = "URL to access LLM Gateway web interface"
  value       = var.llmgateway_enable ? (var.llmgateway_ingress_enable_tls ? "https://${var.llmgateway_domain}" : "http://${var.llmgateway_domain}") : null
}

output "llmgateway_gateway_url" {
  description = "URL for LLM Gateway API endpoint (OpenAI compatible)"
  value       = var.llmgateway_enable ? "${local.llmgateway_scheme}://${local.llmgateway_gateway_domain}" : null
}
