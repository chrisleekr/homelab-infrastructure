variable "cloudflare_tunnel_token" {
  description = "Remotely-managed Cloudflare Tunnel token (sensitive). Not self-generated; Cloudflare issues it per tunnel. Get it: dashboard > Zero Trust > Networks > Tunnels > Create a tunnel > cloudflared > name it > Save; on the install screen copy the value after --token (the eyJ... string)."
  type        = string
  sensitive   = true
}

variable "cloudflare_tunnel_chart_version" {
  description = "cloudflare-tunnel-remote Helm chart version. Pin it: `helm repo add cloudflare https://cloudflare.github.io/helm-charts && helm show chart cloudflare/cloudflare-tunnel-remote`."
  type        = string
}

variable "cloudflare_tunnel_image_tag" {
  description = "cloudflared image tag to pin. Empty uses the chart default. Pin to a current release from https://github.com/cloudflare/cloudflared/releases."
  type        = string
  default     = ""
}

variable "cloudflare_tunnel_replica_count" {
  description = "Number of cloudflared replicas. HA only, do NOT autoscale (downscaling breaks live connections)."
  type        = number
  default     = 2
}
