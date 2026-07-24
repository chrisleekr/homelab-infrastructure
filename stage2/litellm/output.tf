# Output values for the LiteLLM module. All null while the module is disabled.

output "litellm_namespace" {
  description = "Kubernetes namespace where LiteLLM is deployed"
  value       = var.litellm_enable ? local.litellm_namespace : null
}

output "litellm_service_name" {
  description = "Name of the LiteLLM Kubernetes service, pinned by fullnameOverride in the Helm values"
  value       = var.litellm_enable ? local.litellm_service_name : null
}

output "litellm_api_url" {
  description = "Base URL of the OpenAI-compatible API endpoint"
  value       = var.litellm_enable ? "${local.litellm_scheme}://${var.litellm_domain}" : null
}

output "litellm_ui_url" {
  description = "URL of the LiteLLM admin console, protected by oauth2-proxy"
  value       = var.litellm_enable ? "${local.litellm_scheme}://${var.litellm_domain}/ui" : null
}
