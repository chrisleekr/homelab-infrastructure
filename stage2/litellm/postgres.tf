# Module-owned PostgreSQL.
#
# The chart's db.deployStandalone path is deliberately not used: it generates its own credentials
# Secret from plaintext Helm values, which would put the password into the Helm release secret and
# into Terraform state. Bitnami's postgresql image is also 404 on Docker Hub since the Aug-2025
# catalog migration. Upstream postgres:<tag>-alpine is actively patched and takes its credentials
# from the module-owned litellm-db Secret.

# Two Services on purpose.
#
# This one is what clients connect to: a normal ClusterIP, so the LiteLLM Deployment and the
# migrations Job resolve a stable virtual IP. It is the name handed to the chart as db.endpoint.
resource "kubernetes_service_v1" "postgres" {
  count = var.litellm_enable ? 1 : 0

  metadata {
    name      = "litellm-postgres"
    namespace = local.litellm_namespace
  }

  spec {
    selector = { app = "litellm-postgres" }
    type     = "ClusterIP"

    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }
  }
}

# The governing Service for the StatefulSet. Kubernetes requires spec.serviceName to name a
# HEADLESS Service - it is what gives each replica its stable per-pod DNS record. The ClusterIP
# Service above cannot serve that role, and clients depend on its VIP, so the two stay separate.
resource "kubernetes_service_v1" "postgres_headless" {
  count = var.litellm_enable ? 1 : 0

  metadata {
    name      = "litellm-postgres-headless"
    namespace = local.litellm_namespace
  }

  spec {
    selector   = { app = "litellm-postgres" }
    cluster_ip = "None"

    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_stateful_set_v1" "postgres" {
  count = var.litellm_enable ? 1 : 0

  depends_on = [kubernetes_secret_v1.db]

  metadata {
    name      = "litellm-postgres"
    namespace = local.litellm_namespace
  }

  spec {
    service_name = kubernetes_service_v1.postgres_headless[0].metadata[0].name
    replicas     = 1

    selector {
      match_labels = { app = "litellm-postgres" }
    }

    template {
      metadata {
        labels = { app = "litellm-postgres" }
      }

      spec {
        # Postgres never calls the Kubernetes API. Not mounting the token keeps a live API
        # credential out of the database container.
        automount_service_account_token = false

        security_context {
          # gid 70 is the postgres group inside the alpine image; the Debian variant uses 999.
          # Check with `id postgres` in the chosen image. Without this the Longhorn volume is not
          # writable. litellm_postgres_image_tag is constrained to -alpine tags so this holds.
          fs_group = 70
        }

        container {
          name  = "postgres"
          image = "postgres:${var.litellm_postgres_image_tag}"

          security_context {
            # The entrypoint starts as root, chowns PGDATA, then su-exec's to postgres. Dropping
            # privileges is still permitted under no_new_privs, so this is safe here. Capabilities
            # are intentionally not dropped: that same entrypoint needs CHOWN/SETUID/SETGID.
            allow_privilege_escalation = false
          }

          # PGDATA must be a subdirectory of the mount point: initdb refuses a directory that
          # already contains lost+found.
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          env {
            name  = "POSTGRES_DB"
            value = local.litellm_db_name
          }

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.db[0].metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.db[0].metadata[0].name
                key  = "password"
              }
            }
          }

          port {
            name           = "postgres"
            container_port = 5432
            protocol       = "TCP"
          }

          # Idle footprint is small (tens of Mi, near-zero CPU). The request covers idle; the limit
          # leaves room for connection growth and autovacuum bursts.
          resources {
            requests = {
              cpu    = "25m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }

          # Holds the liveness probe off for up to 5 minutes. After an unclean shutdown, WAL crash
          # recovery can easily outlast the liveness budget below, and a kubelet restart mid
          # recovery only makes recovery start over.
          startup_probe {
            exec {
              command = local.litellm_pg_isready_command
            }
            period_seconds    = 10
            timeout_seconds   = 5
            failure_threshold = 30
          }

          readiness_probe {
            exec {
              command = local.litellm_pg_isready_command
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          liveness_probe {
            exec {
              command = local.litellm_pg_isready_command
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.litellm_storage_class_name

        resources {
          requests = {
            storage = var.litellm_storage_size
          }
        }
      }
    }
  }
}
