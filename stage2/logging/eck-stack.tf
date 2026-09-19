resource "kubectl_manifest" "max_map_count_setter" {
  depends_on = [
    null_resource.eck_operator_ready
  ]

  yaml_body = templatefile(
    "${path.module}/templates/eck/max-map-count-setter.tftpl",
    {
      namespace = kubernetes_namespace_v1.logging.metadata[0].name
    }
  )
}

resource "kubectl_manifest" "elasticsearch" {
  depends_on = [
    kubectl_manifest.max_map_count_setter,
    kubernetes_secret_v1.elasticsearch_secret
  ]

  yaml_body = templatefile(
    "${path.module}/templates/eck/elasticsearch.tftpl",
    {
      namespace = kubernetes_namespace_v1.logging.metadata[0].name

      resource_request_memory = var.elasticsearch_resource_request_memory
      resource_request_cpu    = var.elasticsearch_resource_request_cpu
      resource_limit_memory   = var.elasticsearch_resource_limit_memory
      resource_limit_cpu      = var.elasticsearch_resource_limit_cpu

      storage_size       = var.elasticsearch_storage_size
      storage_class_name = var.elasticsearch_storage_class_name
    }
  )
}

resource "null_resource" "elasticsearch_ready" {
  depends_on = [
    kubectl_manifest.elasticsearch
  ]

  triggers = {
    elasticsearch_ready = kubectl_manifest.elasticsearch.id
  }


  provisioner "local-exec" {
    command = <<-EOT
      end=$((SECONDS+300))
      until kubectl wait --for=condition=ready --timeout=300s --namespace ${kubernetes_namespace_v1.logging.metadata[0].name} pod -l elasticsearch.k8s.elastic.co/cluster-name=elasticsearch || [ $SECONDS -ge $end ]; do
        echo "Waiting for Kibana pod to be ready..."
        sleep 10
      done
    EOT
  }
}

# Comment out because ilm will be created by post setup.
# resource "kubernetes_config_map_v1" "filebeat_ilm" {
#   depends_on = [
#     kubectl_manifest.elasticsearch
#   ]

#   metadata {
#     name      = "filebeat-ilm"
#     namespace = kubernetes_namespace_v1.logging.metadata[0].name
#   }

#   data = {
#     "policy.json" = file("${path.module}/templates/eck/filebeat-ilm-policy.json")
#   }
# }


resource "kubectl_manifest" "kibana" {
  depends_on = [
    kubectl_manifest.elasticsearch
  ]

  yaml_body = templatefile(
    "${path.module}/templates/eck/kibana.tftpl",
    {
      namespace = kubernetes_namespace_v1.logging.metadata[0].name

      resource_request_memory = var.kibana_resource_request_memory
      resource_limit_memory   = var.kibana_resource_limit_memory

      # Always https. The host is served by the Istio gateway, which terminates TLS for it,
      # so publicBaseUrl must match the scheme the browser actually used.
      kibana_domain = "https://${var.kibana_domain}"

    }
  )
}

resource "null_resource" "kibana_ready" {
  depends_on = [
    kubectl_manifest.kibana
  ]

  triggers = {
    kibana_ready = kubectl_manifest.kibana.id
  }


  provisioner "local-exec" {
    command = <<-EOT
      end=$((SECONDS+300))
      until kubectl wait --for=condition=ready --timeout=300s --namespace ${kubernetes_namespace_v1.logging.metadata[0].name} pod -l kibana.k8s.elastic.co/name=kibana || [ $SECONDS -ge $end ]; do
        echo "Waiting for Kibana pod to be ready..."
        sleep 10
      done
    EOT
  }
}

resource "kubernetes_manifest" "filebeat_cluster_role" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRole"
    "metadata" = {
      "name" = "filebeat"
    }
    "rules" = [
      {
        "apiGroups" = [""]
        "resources" = ["namespaces", "pods", "nodes"]
        "verbs"     = ["get", "watch", "list"]
      },
    ]
  }
}

resource "kubernetes_manifest" "filebeat_service_account" {
  depends_on = [
    kubernetes_namespace_v1.logging,
    kubernetes_manifest.filebeat_cluster_role
  ]

  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ServiceAccount"
    "metadata" = {
      "name"      = "filebeat"
      "namespace" = kubernetes_namespace_v1.logging.metadata[0].name
    }
  }
}

resource "kubernetes_manifest" "filebeat_cluster_role_binding" {
  depends_on = [
    kubernetes_manifest.filebeat_service_account
  ]

  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRoleBinding"
    "metadata" = {
      "name" = "filebeat"
    }
    "subjects" = [
      {
        "kind"      = "ServiceAccount"
        "name"      = "filebeat"
        "namespace" = kubernetes_namespace_v1.logging.metadata[0].name
      }
    ]
    "roleRef" = {
      "kind"     = "ClusterRole"
      "name"     = "filebeat"
      "apiGroup" = "rbac.authorization.k8s.io"
    }
  }
}

resource "kubectl_manifest" "filebeat" {
  depends_on = [
    kubectl_manifest.elasticsearch,
    kubernetes_job_v1.elasticsearch_post_setup,
    kubernetes_manifest.filebeat_cluster_role,
    kubernetes_manifest.filebeat_service_account,
    kubernetes_manifest.filebeat_cluster_role_binding,
  ]

  yaml_body = templatefile(
    "${path.module}/templates/eck/filebeat.tftpl",
    {
      namespace = kubernetes_namespace_v1.logging.metadata[0].name
    }
  )
}

resource "kubernetes_manifest" "metricbeat_service_account" {
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ServiceAccount"
    "metadata" = {
      "name"      = "metricbeat"
      "namespace" = kubernetes_namespace_v1.logging.metadata[0].name
    }
  }
}

resource "kubernetes_manifest" "metricbeat_cluster_role" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRole"
    "metadata" = {
      "name" = "metricbeat"
    }
    "rules" = [
      {
        "apiGroups" = [""]
        "resources" = ["nodes", "namespaces", "events", "pods"]
        "verbs"     = ["get", "list", "watch"]
      },
      {
        "apiGroups" = ["extensions"]
        "resources" = ["replicasets"]
        "verbs"     = ["get", "list", "watch"]
      },
      {
        "apiGroups" = ["apps"]
        "resources" = ["statefulsets", "deployments", "replicasets"]
        "verbs"     = ["get", "list", "watch"]
      },
      {
        "apiGroups" = [""]
        "resources" = ["nodes/stats"]
        "verbs"     = ["get"]
      }
    ]
  }
}

resource "kubernetes_manifest" "metricbeat_cluster_role_binding" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRoleBinding"
    "metadata" = {
      "name" = "metricbeat"
    }
    "subjects" = [
      {
        "kind"      = "ServiceAccount"
        "name"      = "metricbeat"
        "namespace" = kubernetes_namespace_v1.logging.metadata[0].name
      }
    ]
    "roleRef" = {
      "kind"     = "ClusterRole"
      "name"     = "metricbeat"
      "apiGroup" = "rbac.authorization.k8s.io"
    }
  }
}

resource "kubectl_manifest" "metricbeat" {
  depends_on = [
    kubectl_manifest.elasticsearch,
    kubernetes_manifest.metricbeat_service_account,
    kubernetes_manifest.metricbeat_cluster_role,
    kubernetes_manifest.metricbeat_cluster_role_binding
  ]

  yaml_body = templatefile(
    "${path.module}/templates/eck/metricbeat.tftpl",
    {
      namespace              = kubernetes_namespace_v1.logging.metadata[0].name
      elasticsearch_password = random_password.elastic_password.result
      node_name              = "kubernetes.default.svc"
    }
  )
}
