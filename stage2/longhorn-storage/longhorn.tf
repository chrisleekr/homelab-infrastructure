resource "kubernetes_namespace_v1" "longhorn" {
  metadata {
    name = "longhorn-system"

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


resource "kubernetes_secret_v1" "frontend_basic_auth" {
  metadata {
    name      = "frontend-basic-auth"
    namespace = kubernetes_namespace_v1.longhorn.metadata[0].name
  }

  data = {
    auth = base64decode(var.nginx_frontend_basic_auth_base64)
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

# defaultSettings.createDefaultDiskLabeledNodes gates default-disk creation on this label,
# and Longhorn only evaluates it the first time it detects a node. Labelling here keeps the
# storage topology reproducible: without it a rebuilt control plane gets no disk and every
# PVC stays Pending, with nothing failing at apply time to signal why.
data "kubernetes_nodes" "control_plane" {
  metadata {
    labels = {
      "node-role.kubernetes.io/control-plane" = ""
    }
  }

  lifecycle {
    postcondition {
      condition     = length(self.nodes) > 0
      error_message = "No control-plane node matched. Longhorn would create no default disk and every PVC would stay Pending."
    }
  }
}

# Deliberately not for_each/count over the node list. This module carries a module-level
# depends_on in main.tf, which defers the data source read to apply whenever the upstream
# module has pending changes, leaving for_each keys unknown and failing the plan. A plain
# attribute reference tolerates an unknown value. One control plane, so index 0 is the node.
resource "kubernetes_labels" "longhorn_default_disk" {
  api_version = "v1"
  kind        = "Node"

  metadata {
    name = data.kubernetes_nodes.control_plane.nodes[0].metadata[0].name
  }

  labels = {
    "node.longhorn.io/create-default-disk" = "true"
  }

  # The label predates this resource on existing clusters, so adopt it instead of conflicting.
  # force also makes Terraform sole owner, so destroying this strips the label. Harmless while
  # Longhorn runs, since it only re-reads the label on first node detection.
  force = true
}

resource "helm_release" "longhorn" {
  # Label must exist before Longhorn first detects the node, or no default disk is created.
  depends_on = [kubernetes_namespace_v1.longhorn, kubernetes_labels.longhorn_default_disk]

  name       = "longhorn"
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  namespace  = kubernetes_namespace_v1.longhorn.metadata[0].name
  version    = "1.10.1"
  wait       = true
  timeout    = 300

  values = [
    templatefile(
      "${path.module}/templates/longhorn-values.tftpl",
      {
        auth_oauth2_proxy_host                      = var.auth_oauth2_proxy_host
        frontend_basic_auth_secret_name             = kubernetes_secret_v1.frontend_basic_auth.metadata[0].name
        longhorn_default_settings_default_data_path = var.longhorn_default_settings_default_data_path
        longhorn_ingress_class_name                 = var.longhorn_ingress_class_name
        longhorn_ingress_host                       = var.longhorn_ingress_host
        longhorn_ingress_enable_tls                 = var.longhorn_ingress_enable_tls
      }
    ),
  ]
}

resource "null_resource" "remove_default" {
  depends_on = [helm_release.longhorn]
  provisioner "local-exec" {
    command = <<EOT
if kubectl get storageclass local-path; then
  kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
fi
EOT
  }
}
