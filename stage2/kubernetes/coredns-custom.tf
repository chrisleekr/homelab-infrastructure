# My internet provider does not support hairpin NAT, so I need to use the custom coredns config to avoid it.

# Configure the coredns custom configmap to avoid hairpin NAT issue.
resource "kubernetes_config_map" "coredns_custom" {
  metadata {
    name      = "coredns-custom"
    namespace = "kube-system"
  }

  data = {
    "default.server"   = <<EOF
${trim(var.kubernetes_override_domains, "\"")} {
    hosts {
          ${var.kubernetes_override_ip} ${trim(var.kubernetes_override_domains, "\"")}
          fallthrough
    }
}
EOF
    "default.override" = ""
  }
}

# When kubernetes_cluster_type is kubeadm, then patch the coredns configmap to load the custom coredns config. This is to avoid hairpin NAT issue.
# Reference: https://github.com/k3s-io/k3s/blob/master/manifests/coredns.yaml#L75
resource "null_resource" "patch_coredns_configmap" {
  count = var.kubernetes_cluster_type == "kubeadm" ? 1 : 0

  triggers = {
    kubernetes_cluster_type     = var.kubernetes_cluster_type
    kubernetes_override_domains = var.kubernetes_override_domains
    # always_run          = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOT
      kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-configmap.yaml
      sed -i '/loadbalance/a \ \ \ \ \ \ \ \ import /etc/coredns/custom/*.override' /tmp/coredns-configmap.yaml
      sed -i '/^    }$/a \ \ \ \ import /etc/coredns/custom/*.server'  /tmp/coredns-configmap.yaml
      kubectl apply -f /tmp/coredns-configmap.yaml
    EOT
  }
}

# When kubernetes_cluster_type is kubeadm, then patch the coredns deployment to load the custom coredns configmap. This is to avoid hairpin NAT issue.
resource "null_resource" "patch_coredns_deployment" {
  count = var.kubernetes_cluster_type == "kubeadm" ? 1 : 0

  triggers = {
    kubernetes_cluster_type     = var.kubernetes_cluster_type
    kubernetes_override_domains = var.kubernetes_override_domains
    # always_run          = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOT
      kubectl patch deployment coredns -n kube-system --type json -p '[{"op": "add", "path": "/spec/template/spec/volumes/-", "value": {"name": "coredns-custom", "configMap": {"name": "coredns-custom", "optional": true}}}, {"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/-", "value": {"name": "coredns-custom", "mountPath": "/etc/coredns/custom", "readOnly": true}}]'
    EOT
  }
}
