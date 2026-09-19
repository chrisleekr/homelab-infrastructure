# Scrape targets for the gateway and the control plane.
#
# PodMonitor, not the prometheus.io scrape annotations the gateway pod already carries: this
# Prometheus discovers targets through the operator CRDs and ignores those annotations entirely.
# Datadog does read them, so with datadog_enable the metrics arrive there either way; these two
# objects are what put the same data in front of the alert rules in stage2/monitoring.
#
# No selector label is needed. The stack sets podMonitorSelector.matchLabels to null, which selects
# every PodMonitor in the cluster.
resource "kubectl_manifest" "gateway_podmonitor" {
  depends_on = [kubectl_manifest.gateway]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      name      = "istio-gateway"
      namespace = var.istio_gateway_namespace
    }
    spec = {
      # Istio stamps this label on the Deployment it auto-provisions for the Gateway, so the
      # selector follows the Gateway rather than the generated pod name.
      selector = {
        matchLabels = {
          "gateway.networking.k8s.io/gateway-name" = var.istio_gateway_name
        }
      }
      podMetricsEndpoints = [{
        # Port 15020 on the istio-proxy container. It merges Envoy's own stats into the Istio
        # telemetry, which is why this is the port to scrape rather than 15090.
        port = "metrics"
        path = "/stats/prometheus"
      }]
    }
  })
}

resource "kubectl_manifest" "istiod_podmonitor" {
  depends_on = [helm_release.istiod]

  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      name      = "istiod"
      namespace = var.istio_gateway_control_plane_namespace
    }
    spec = {
      selector = {
        matchLabels = {
          app = "istiod"
        }
      }
      podMetricsEndpoints = [{
        port = "http-monitoring"
      }]
    }
  })
}
