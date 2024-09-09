resource "kubectl_manifest" "max_map_count_setter" {
  depends_on = [
    null_resource.eck_operator_ready
  ]

  yaml_body = templatefile(
    "${path.module}/templates/max-map-count-setter.tftpl",
    {
      namespace = kubernetes_namespace.elastic_system.metadata[0].name
    }
  )
}


resource "kubectl_manifest" "elasticsearch" {
  depends_on = [
    kubectl_manifest.max_map_count_setter
  ]

  yaml_body = templatefile(
    "${path.module}/templates/elasticsearch.tftpl",
    {
      namespace = kubernetes_namespace.elastic_system.metadata[0].name

      resourceRequestMemory = var.elasticsearch_resource_request_memory
      resourceRequestCPU    = var.elasticsearch_resource_request_cpu
      resourceLimitMemory   = var.elasticsearch_resource_limit_memory
      resourceLimitCPU      = var.elasticsearch_resource_limit_cpu

      storageSize      = var.elasticsearch_storage_size
      storageClassName = var.elasticsearch_storage_class_name
    }
  )
}
