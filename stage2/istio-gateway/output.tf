output "istio_gateway_namespace" {
  description = "Namespace holding the Gateway and its generated Deployment and Service"
  value       = var.istio_gateway_namespace
}

# The tunnel origin for every migrated hostname: https://<this>:443 with No TLS Verify and
# Origin Server Name set to the hostname.
output "istio_gateway_service" {
  description = "Cluster DNS name of the gateway Service that Cloudflare Tunnel routes point at"
  value       = "${var.istio_gateway_name}-istio.${var.istio_gateway_namespace}.svc"
}

output "istio_gateway_name" {
  description = "Gateway resource name. App modules take the root var.istio_gateway_name for their ListenerSet parentRef, not this output"
  value       = var.istio_gateway_name
}
