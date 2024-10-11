output "elasticsearch_password" {
  value     = random_password.elastic_password.result
  sensitive = true
}
