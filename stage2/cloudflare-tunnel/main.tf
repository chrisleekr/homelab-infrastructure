resource "kubernetes_namespace_v1" "cloudflare_tunnel" {
  metadata {
    name = "cloudflare-tunnel"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "homelab"
    }
  }
}

# Remotely-managed Cloudflare Tunnel connector (cloudflared).
#
# Scope of this module: it ONLY runs the connector. The tunnel itself, its public
# hostnames (all -> the ingress-nginx service), the DNS records, and Cloudflare Access
# policies are managed in the Cloudflare dashboard. The remote-managed connector model
# keeps that config server-side (delivered via the tunnel token), so Terraform needs
# only the token and never holds the routing config. See this module's README.
#
# Requirements:
#   - The cluster must reach Cloudflare outbound on TCP 7844 (tunnel) and 443.
#   - Each replica reaches every in-cluster service; the tunnel's single catch-all public
#     hostname points at https://nginx-ingress-nginx-controller.nginx.svc:443 (No TLS Verify),
#     and ingress-nginx routes by Host as usual.
#
# Chart: https://github.com/cloudflare/helm-charts (chart: cloudflare-tunnel-remote)
resource "helm_release" "cloudflare_tunnel" {
  depends_on = [kubernetes_namespace_v1.cloudflare_tunnel]

  name       = "cloudflare-tunnel"
  repository = "https://cloudflare.github.io/helm-charts"
  chart      = "cloudflare-tunnel-remote"
  version    = var.cloudflare_tunnel_chart_version
  namespace  = kubernetes_namespace_v1.cloudflare_tunnel.metadata[0].name
  timeout    = 300
  wait       = true

  set_sensitive = [
    {
      name  = "cloudflare.tunnel_token"
      value = var.cloudflare_tunnel_token
    }
  ]

  set = concat(
    [
      {
        name  = "replicaCount"
        value = tostring(var.cloudflare_tunnel_replica_count)
      }
    ],
    var.cloudflare_tunnel_image_tag != "" ? [
      {
        name  = "image.tag"
        value = var.cloudflare_tunnel_image_tag
      }
    ] : []
  )
}
