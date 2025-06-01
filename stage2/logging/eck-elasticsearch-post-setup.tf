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

resource "kubernetes_job" "elasticsearch_post_setup" {
  # Add data source dependency
  depends_on = [
    kubernetes_config_map.elasticsearch_setup_script,
    data.kubernetes_resource.elasticsearch,
    random_password.elastic_password
  ]

  metadata {
    name      = "elasticsearch-post-setup"
    namespace = kubernetes_namespace.logging.metadata[0].name
  }

  spec {
    template {
      metadata {
        # Add elasticsearch version to force job recreation when elasticsearch changes
        annotations = {
          "elasticsearch-version" = data.kubernetes_resource.elasticsearch.object.spec.version
        }
      }

      spec {
        container {
          name  = "elasticsearch-post-setup"
          image = "alpine:3.18"

          env {
            name  = "ELASTIC_PASSWORD"
            value = random_password.elastic_password.result
          }

          env {
            name  = "ELASTICSEARCH_URL"
            value = "http://elasticsearch-es-http.${kubernetes_namespace.logging.metadata[0].name}.svc:9200"
          }

          volume_mount {
            name       = "setup-script"
            mount_path = "/scripts"
          }

          command = ["/bin/sh"]
          args    = ["/scripts/elasticsearch-post-setup.sh"]
        }

        volume {
          name = "setup-script"
          config_map {
            name         = kubernetes_config_map.elasticsearch_setup_script.metadata[0].name
            default_mode = "0755"
          }
        }

        restart_policy = "Never"
      }
    }

    backoff_limit = 1
  }

  timeouts {
    create = "3m"
    update = "3m"
  }

  wait_for_completion = true
}
