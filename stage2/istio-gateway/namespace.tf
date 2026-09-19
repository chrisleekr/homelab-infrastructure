# Two namespaces, because the control plane and the data plane have different blast radii.
# istiod lives in the root namespace, where it also reads mesh-wide config; the Gateway and its
# generated Deployment, Service and TLS Secrets live apart, so a Gateway change cannot touch istiod.
resource "kubernetes_namespace_v1" "istio_system" {
  metadata {
    name = var.istio_gateway_control_plane_namespace

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "homelab"
    }
  }
}

resource "kubernetes_namespace_v1" "istio_ingress" {
  metadata {
    name = var.istio_gateway_namespace

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "homelab"
    }
  }
}
