output "prometheus_operator_version" {
  description = "Prometheus Operator version packaged by both compatible charts."
  value       = data.external.prometheus_chart_compatibility.result["operator_version"]
}
