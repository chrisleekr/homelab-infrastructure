output "elasticsearch_host" {
  value = "elasticsearch-es-internal-http.${kubernetes_namespace.logging.metadata[0].name}.svc"
}

output "elasticsearch_port" {
  value = 9200 # Default
}

output "elasticsearch_username" {
  value = "elastic" # Default
}

output "elasticsearch_password" {
  value     = random_password.elastic_password.result
  sensitive = true
}
