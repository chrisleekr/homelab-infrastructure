output "elasticsearch_host" {
  description = "The internal Kubernetes service hostname for Elasticsearch"
  value       = "elasticsearch-es-internal-http.${kubernetes_namespace.logging.metadata[0].name}.svc"
}

output "elasticsearch_port" {
  description = "The port number for Elasticsearch HTTP API"
  value       = 9200 # Default
}

output "elasticsearch_username" {
  description = "The username for Elasticsearch authentication"
  value       = "elastic" # Default
}

output "elasticsearch_password" {
  description = "The password for the elastic superuser account"
  value       = random_password.elastic_password.result
  sensitive   = true
}
