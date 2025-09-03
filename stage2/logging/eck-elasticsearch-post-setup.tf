# Add data source to get Elasticsearch configuration
data "kubernetes_resource" "elasticsearch" {
  api_version = "elasticsearch.k8s.elastic.co/v1"
  kind        = "Elasticsearch"

  metadata {
    name      = "elasticsearch"
    namespace = kubernetes_namespace.logging.metadata[0].name
  }
}

# Create ConfigMap for the setup script and templates
resource "kubernetes_config_map" "elasticsearch_setup_script" {
  metadata {
    name      = "elasticsearch-setup-script"
    namespace = kubernetes_namespace.logging.metadata[0].name
  }

  data = {
    "elasticsearch-post-setup.sh" = file("${path.module}/scripts/elasticsearch-post-setup.sh")
    "filebeat-custom.json"        = file("${path.module}/scripts/filebeat-custom.json")
  }
}

# Create ConfigMap for the setup script and templates
resource "kubectl_manifest" "elasticsearch_post_setup" {
  depends_on = [
    kubernetes_config_map.elasticsearch_setup_script,
    data.kubernetes_resource.elasticsearch,
    random_password.elastic_password
  ]

  yaml_body = yamlencode({
    apiVersion = "batch/v1"
    kind       = "Job"
    metadata = {
      name      = "elasticsearch-post-setup"
      namespace = kubernetes_namespace.logging.metadata[0].name
      # Add elasticsearch version to force job recreation when elasticsearch changes
      annotations = {
        "elasticsearch-version" = data.kubernetes_resource.elasticsearch.object.spec.version
      }
    }
    spec = {
      backoffLimit = 1
      # Add TTL to automatically clean up completed jobs
      ttlSecondsAfterFinished = 300
      template = {
        metadata = {
          # Add elasticsearch version to force job recreation when elasticsearch changes
          annotations = {
            "elasticsearch-version" = data.kubernetes_resource.elasticsearch.object.spec.version
          }
        }
        spec = {
          restartPolicy = "Never"
          containers = [{
            name  = "elasticsearch-post-setup"
            image = "alpine:3.18"
            env = [
              {
                name  = "ELASTIC_PASSWORD"
                value = random_password.elastic_password.result
              },
              {
                name  = "ELASTICSEARCH_URL"
                value = "http://elasticsearch-es-http.${kubernetes_namespace.logging.metadata[0].name}.svc:9200"
              }
            ]
            volumeMounts = [{
              name      = "setup-script"
              mountPath = "/scripts"
            }]
            command = ["/bin/sh"]
            args    = ["/scripts/elasticsearch-post-setup.sh"]
          }]
          volumes = [{
            name = "setup-script"
            configMap = {
              name        = kubernetes_config_map.elasticsearch_setup_script.metadata[0].name
              defaultMode = 493 # 0755 in decimal
            }
          }]
        }
      }
    }
  })

  timeouts {
    create = "3m"
  }

}
