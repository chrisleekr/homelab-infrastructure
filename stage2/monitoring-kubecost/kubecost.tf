resource "kubernetes_namespace_v1" "kubecost" {
  metadata {
    name = "kubecost"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "homelab"
    }
  }

  # Required module: guards against accidental destruction. To intentionally destroy, set prevent_destroy = false, apply, then revert.
  lifecycle {
    prevent_destroy = true
  }
}


resource "kubernetes_secret_v1" "federated_store" {
  depends_on = [kubernetes_namespace_v1.kubecost]

  metadata {
    name      = "kubecost-federated-store"
    namespace = kubernetes_namespace_v1.kubecost.metadata[0].name
  }

  data = {
    "federated-store.yaml" = templatefile(
      "${path.module}/templates/federated-store.yaml.tftpl",
      {
        minio_endpoint   = var.minio_endpoint
        minio_bucket     = var.minio_bucket_name
        minio_access_key = var.minio_access_key
        minio_secret_key = var.minio_secret_key
      }
    )
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

# https://github.com/kubecost/kubecost/blob/develop/README.md#config-options
#
# 3.x ships from a different repo under a different chart name; the pre-3.0 `cost-analyzer` chart
# tops out at 2.9.7, whose cost-model container panics on start by design. Release name is kept so
# the upgrade lands on the existing release rather than orphaning it.
resource "helm_release" "kubecost" {
  depends_on = [
    kubernetes_namespace_v1.kubecost,
    kubernetes_secret_v1.federated_store,
  ]

  name       = "cost-analyzer"
  repository = "https://kubecost.github.io/kubecost"
  chart      = "kubecost"
  namespace  = kubernetes_namespace_v1.kubecost.metadata[0].name
  # https://github.com/kubecost/kubecost/releases
  version = "3.2.1"
  wait    = true
  # 3.x splits the single cost-analyzer pod into four workloads, each pulling its own image and
  # waiting on a Longhorn volume. 300s was already marginal and timed out on the 2.9.7 upgrade.
  timeout = 900

  values = [
    templatefile(
      "${path.module}/templates/kubecost-values.tftpl",
      {
        cluster_id             = var.kubecost_cluster_id
        auth_oauth2_proxy_host = var.auth_oauth2_proxy_host
        storage_class_name     = var.kubecost_storage_class_name

        ingress_enable_tls = var.kubecost_ingress_enable_tls
        ingress_class_name = var.kubecost_ingress_class_name

        kubecost_ingress_host = var.kubecost_ingress_host

        federated_store_secret_name = kubernetes_secret_v1.federated_store.metadata[0].name
      }
    )
  ]
}
