variable "cert_manager_cloudflare_api_token" {
  description = "Cloudflare API token for the DNS-01 solver. Needs Zone:DNS:Edit plus Zone:Zone:Read, because the provider looks the zone id up by name. The root module's validation requires it"
  type        = string
  sensitive   = true
  default     = ""
}
