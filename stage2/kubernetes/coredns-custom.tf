resource "kubernetes_config_map" "coredns_custom" {
  metadata {
    name      = "coredns-custom"
    namespace = "kube-system"
  }

  data = {
    "default.server" = <<EOF
${trim(var.kubernetes_override_domains, "\"")} {
    hosts {
          ${var.kubernetes_override_ip} ${trim(var.kubernetes_override_domains, "\"")}
          fallthrough
    }
}
EOF
  }
}
