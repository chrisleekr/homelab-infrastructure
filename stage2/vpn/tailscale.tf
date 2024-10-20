resource "kubernetes_secret" "tailscale_auth_key" {
  count = var.tailscale_enable ? 1 : 0

  depends_on = [
    kubernetes_namespace.vpn_namespace
  ]
  metadata {
    name      = "tailscale-auth-key"
    namespace = kubernetes_namespace.vpn_namespace.metadata[0].name
  }

  data = {
    auth-key = var.tailscale_auth_key
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "kubernetes_role_v1" "tailscale" {
  count = var.tailscale_enable ? 1 : 0

  metadata {
    name      = "tailscale"
    namespace = kubernetes_namespace.vpn_namespace.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create"]
  }

  rule {
    api_groups     = [""]
    resource_names = ["tailscale-secret"]
    resources      = ["secrets"]
    verbs          = ["get", "update", "patch"]
  }
}

resource "kubernetes_service_account_v1" "tailscale" {
  count = var.tailscale_enable ? 1 : 0

  metadata {
    name      = "tailscale-sa"
    namespace = kubernetes_namespace.vpn_namespace.metadata[0].name
  }
}

resource "kubernetes_role_binding_v1" "tailscale" {
  count = var.tailscale_enable ? 1 : 0

  metadata {
    name      = "tailscale"
    namespace = kubernetes_namespace.vpn_namespace.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "tailscale-sa"
    namespace = kubernetes_namespace.vpn_namespace.metadata[0].name
  }

  role_ref {
    kind      = "Role"
    name      = "tailscale"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_deployment_v1" "tailscale" {
  count = var.tailscale_enable ? 1 : 0

  timeouts {
    create = "5m"
    update = "5m"
    delete = "5m"
  }

  metadata {
    name      = "tailscale"
    namespace = kubernetes_namespace.vpn_namespace.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "tailscale"
      }
    }

    template {
      metadata {
        labels = {
          app = "tailscale"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.tailscale[0].metadata[0].name

        init_container {
          image = "busybox:latest"
          name  = "sysctler"
          security_context {
            privileged = true
          }

          command = ["/bin/sh"]
          args    = ["-c", "sysctl -w net.ipv4.ip_forward=1 net.ipv6.conf.all.forwarding=1"]
        }

        container {
          image = "tailscale/tailscale:v1.76.1"
          name  = "tailscale"

          env {
            name  = "TS_EXTRA_ARGS"
            value = "--advertise-tags=tag:kubernetes --accept-routes --advertise-exit-node --advertise-routes=${var.tailscale_advertise_routes}"
          }

          env {
            name  = "TS_HOSTNAME"
            value = var.tailscale_hostname
          }

          env {
            name  = "TS_USERSPACE"
            value = "false"
          }

          env {
            name  = "TZ"
            value = var.tailscale_timezone
          }

          env {
            name  = "TS_KUBE_SECRET"
            value = "tailscale-secret"
          }

          env {
            name = "TS_AUTH_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tailscale_auth_key[0].metadata[0].name
                key  = "auth-key"
              }
            }
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "256Mi"
            }
            limits = {
              memory = "256Mi"
            }
          }

          security_context {
            privileged = true
            capabilities {
              add = [
                "NET_ADMIN",
                "NET_RAW",
              ]
            }
          }

          volume_mount {
            name       = "tun-device"
            mount_path = "/dev/net/tun"
            read_only  = false
          }
        }
        volume {
          name = "tun-device"
          host_path {
            path = "/dev/net/tun"
          }
        }

      }
    }
  }
}
