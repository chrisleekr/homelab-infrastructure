
# Probes the LAN, WAN and DNS path from inside the cluster, so an outage leaves a time series
# showing which hop failed. Each target is a ServiceMonitor that the stack's Prometheus selects.
resource "helm_release" "blackbox_exporter" {
  name       = "prometheus-blackbox-exporter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-blackbox-exporter"
  version    = "11.20.1"
  namespace  = kubernetes_namespace_v1.monitoring_namespace.metadata[0].name
  # Default 0 keeps every revision as a Secret that kube-apiserver holds in memory.
  max_history = 3

  values = [
    templatefile(
      "${path.module}/templates/blackbox-exporter-values.tftpl",
      {
        gateway_ip      = var.prometheus_blackbox_gateway_ip
        lan_dns_servers = var.prometheus_blackbox_lan_dns_servers
        http_targets    = var.prometheus_blackbox_http_targets
      }
    )
  ]
}
