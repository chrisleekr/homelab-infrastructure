data "external" "prometheus_chart_compatibility" {
  program = [
    "python3",
    abspath("${path.module}/scripts/check-prometheus-chart-compatibility.py"),
    "--terraform",
  ]

  lifecycle {
    postcondition {
      condition     = lookup(self.result, "compatible", "false") == "true"
      error_message = "The Prometheus CRD and stack charts must package the same Prometheus Operator version."
    }
  }
}
