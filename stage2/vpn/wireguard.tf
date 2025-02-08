
resource "kubernetes_persistent_volume_claim_v1" "wireguard_config" {
  metadata {
    name      = "wireguard-config"
    namespace = kubernetes_namespace.vpn_namespace.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "wireguard" {
  count = var.wireguard_enable ? 1 : 0

  depends_on = [
    kubernetes_namespace.vpn_namespace,
    kubernetes_persistent_volume_claim_v1.wireguard_config,
  ]

  timeouts {
    create = "5m"
    update = "5m"
    delete = "5m"
  }

  metadata {
    name      = "wireguard"
    namespace = kubernetes_namespace.vpn_namespace.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "wireguard"
      }
    }

    template {
      metadata {
        labels = {
          app = "wireguard"
        }
      }

      spec {
        init_container {
          image = "busybox:latest"
          name  = "sysctler"
          security_context {
            privileged = true
          }

          command = ["/bin/sh"]
          args    = ["-c", "sysctl -w net.ipv4.conf.all.src_valid_mark=1"]
        }

        container {
          name  = "wireguard"
          image = "linuxserver/wireguard:1.0.20210914"

          resources {
            requests = {
              cpu    = "10m"
              memory = "37Mi"
            }

            limits = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }

          env {
            name  = "PUID"
            value = "1000"
          }
          env {
            name  = "PGID"
            value = "1000"
          }
          env {
            name  = "TZ"
            value = var.wireguard_timezone
          }
          env {
            name  = "SERVERURL"
            value = var.wireguard_ingress_host
          }
          env {
            name  = "SERVERPORT"
            value = var.wireguard_port
          }
          env {
            name  = "PEERS"
            value = var.wireguard_peers
          }
          env {
            name  = "PEERDNS"
            value = "auto"
          }
          env {
            name  = "INTERNAL_SUBNET"
            value = "10.13.13.0"
          }
          env {
            name  = "ALLOWEDIPS"
            value = "0.0.0.0/0"
          }
          env {
            name  = "LOG_CONFS"
            value = "true"
          }

          security_context {
            privileged = true
            capabilities {
              add = [
                "NET_ADMIN",
                "SYS_MODULE",
              ]
            }
          }

          volume_mount {
            name       = "lib-modules"
            mount_path = "/lib/modules"
            read_only  = true
          }

          port {
            name           = "wireguard"
            container_port = 51820
            protocol       = "UDP"
          }
        }

        volume {
          name = "wireguard-config"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.wireguard_config.metadata[0].name
          }
        }

        volume {
          name = "lib-modules"
          host_path {
            path = "/lib/modules"
          }
        }
      }
    }
  }
}


resource "kubernetes_service_v1" "wireguard" {
  count = var.wireguard_enable ? 1 : 0

  metadata {
    name      = "wireguard"
    namespace = kubernetes_namespace.vpn_namespace.metadata[0].name
  }

  spec {
    selector = {
      app = "wireguard"
    }

    type = "ClusterIP"

    port {
      port        = var.wireguard_port
      target_port = 51820
      protocol    = "UDP"
      name        = "wireguard"
    }
  }
}
