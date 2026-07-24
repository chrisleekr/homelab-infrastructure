# Output values for the OmniRoute module. All null while the module is disabled.

output "omniroute_namespace" {
  description = "Kubernetes namespace where OmniRoute is deployed"
  value       = var.omniroute_enable ? local.omniroute_namespace : null
}

output "omniroute_service_name" {
  description = "Name of the OmniRoute Kubernetes service, pinned by fullnameOverride in the Helm values"
  value       = var.omniroute_enable ? local.omniroute_service_name : null
}

output "omniroute_api_url" {
  description = "Base URL of the OpenAI-compatible API endpoint, open to key-authenticated clients"
  value       = var.omniroute_enable ? "${local.omniroute_scheme}://${var.omniroute_domain}/api/v1" : null
}

output "omniroute_dashboard_url" {
  description = "URL of the OmniRoute dashboard, protected by oauth2-proxy"
  value       = var.omniroute_enable ? "${local.omniroute_scheme}://${var.omniroute_domain}/dashboard" : null
}
