# LLM Gateway Kubernetes Resources
# Deploys the unified LLM Gateway image with embedded PostgreSQL and Redis
# Reference: https://docs.llmgateway.io/self-host

# Derived subdomain URLs for multi-service architecture
# Each service gets its own subdomain to avoid path-based routing complexity
# Reference: https://github.com/theopenco/llmgateway/blob/main/infra/docker-compose.unified.yml
locals {
  llmgateway_scheme         = var.llmgateway_ingress_enable_tls ? "https" : "http"
  llmgateway_api_domain     = "api.${var.llmgateway_domain}"
  llmgateway_gateway_domain = "gateway.${var.llmgateway_domain}"
  llmgateway_admin_domain   = "admin.${var.llmgateway_domain}"
}

# Deployment for LLM Gateway unified container
resource "kubernetes_deployment_v1" "llmgateway" {
  count = var.llmgateway_enable ? 1 : 0

  depends_on = [
    kubernetes_namespace.llmgateway,
    kubernetes_persistent_volume_claim_v1.llmgateway_data,
    kubernetes_secret.llmgateway_auth,
  ]

  timeouts {
    create = "5m"
    update = "5m"
    delete = "5m"
  }

  metadata {
    name      = "llmgateway"
    namespace = kubernetes_namespace.llmgateway[0].metadata[0].name
  }

  spec {
    replicas = var.llmgateway_replicas

    # Note: Recreate strategy required for unified image with embedded PostgreSQL
    # RollingUpdate causes WAL corruption when two pods access RWO PVC simultaneously
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        app = "llmgateway"
      }
    }

    template {
      metadata {
        labels = {
          app = "llmgateway"
        }
      }

      spec {
        # Pod-level security context for volume permissions
        # fsGroup sets group ownership of mounted volumes to PostgreSQL group (GID 102)
        # Kubernetes recursively changes group ownership and sets group-writable permissions
        # Reference: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
        security_context {
          fs_group = 102 # PostgreSQL group in llmgateway-unified image
        }

        # Init container to fix PostgreSQL data directory permissions
        # Required because existing PVC data may have incorrect permissions from earlier attempts
        # PostgreSQL requires mode 0700 or 0750 for data directory
        # Reference: https://www.postgresql.org/docs/current/app-initdb.html
        init_container {
          name  = "fix-permissions"
          image = "busybox:1.36"

          command = [
            "sh", "-c",
            "chown -R 100:102 /var/lib/postgresql && chmod 750 /var/lib/postgresql/data 2>/dev/null || true"
          ]

          security_context {
            run_as_user = 0 # Run as root to change permissions
          }

          volume_mount {
            name       = "llmgateway-data"
            mount_path = "/var/lib/postgresql"
          }
        }

        container {
          name  = "llmgateway"
          image = "ghcr.io/theopenco/llmgateway-unified:${var.llmgateway_image_tag}"

          # Conditional pull policy based on image tag:
          # - "Always" for latest tag ensures newest image is pulled
          # - "IfNotPresent" for versioned tags reduces startup latency
          # Reference: https://kubernetes.io/docs/concepts/containers/images/
          image_pull_policy = var.llmgateway_image_tag == "latest" ? "Always" : "IfNotPresent"

          resources {
            requests = {
              cpu    = "100m"
              memory = "512Mi"
            }

            limits = {
              cpu    = "1000m"
              memory = "2Gi"
            }
          }

          # PGDATA must point to a subdirectory, not the mount point directly
          # This avoids initdb failure due to lost+found directory at mount root
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data"
          }

          # AUTH_SECRET from Kubernetes secret
          env {
            name = "AUTH_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.llmgateway_auth[0].metadata[0].name
                key  = "AUTH_SECRET"
              }
            }
          }

          # URL configuration for subdomain-based deployment
          # Each service has its own subdomain for clean routing without path rewrites
          # Reference: https://github.com/theopenco/llmgateway/blob/main/infra/docker-compose.unified.yml
          env {
            name  = "UI_URL"
            value = "${local.llmgateway_scheme}://${var.llmgateway_domain}"
          }
          env {
            name  = "API_URL"
            value = "${local.llmgateway_scheme}://${local.llmgateway_api_domain}"
          }
          env {
            name  = "API_BACKEND_URL"
            value = "http://localhost:4002" # Internal pod communication stays local
          }
          env {
            name  = "ADMIN_URL"
            value = "${local.llmgateway_scheme}://${local.llmgateway_admin_domain}"
          }
          # ORIGIN_URLS for CORS - all frontends that make cross-origin requests to API
          env {
            name = "ORIGIN_URLS"
            value = join(",", [
              "${local.llmgateway_scheme}://${var.llmgateway_domain}",
              "${local.llmgateway_scheme}://${local.llmgateway_api_domain}",
              "${local.llmgateway_scheme}://${local.llmgateway_admin_domain}",
            ])
          }
          # COOKIE_DOMAIN allows session cookies to work across all subdomains
          # Must be the base domain without subdomain prefix
          env {
            name  = "COOKIE_DOMAIN"
            value = var.llmgateway_domain
          }
          env {
            name  = "PASSKEY_RP_ID"
            value = var.llmgateway_domain
          }

          # Admin emails for admin dashboard access
          # Comma-separated list of emails that have isAdmin=true
          # Reference: https://github.com/theopenco/llmgateway/blob/main/apps/api/src/routes/user.ts
          dynamic "env" {
            for_each = var.llmgateway_admin_emails != "" ? [1] : []
            content {
              name  = "ADMIN_EMAILS"
              value = var.llmgateway_admin_emails
            }
          }

          # Self-hosted mode configuration
          # HOSTED=false and PAID_MODE=false disable the hosted billing restrictions
          # This allows using your own provider API keys (BYOK) without requiring a Pro plan
          # Without these, the gateway enforces credit-based billing even for self-hosted instances
          # Reference: https://github.com/theopenco/llmgateway/blob/main/apps/api/src/routes/projects.ts
          # Reference: https://github.com/theopenco/llmgateway/blob/main/apps/gateway/src/chat/chat.ts
          env {
            name  = "HOSTED"
            value = "false"
          }
          env {
            name  = "PAID_MODE"
            value = "false"
          }

          # Web UI port
          port {
            name           = "ui"
            container_port = 3002
            protocol       = "TCP"
          }

          # API port
          port {
            name           = "api"
            container_port = 4002
            protocol       = "TCP"
          }

          # Gateway port (OpenAI compatible endpoint)
          port {
            name           = "gateway"
            container_port = 4001
            protocol       = "TCP"
          }

          # Documentation port
          port {
            name           = "docs"
            container_port = 3005
            protocol       = "TCP"
          }

          # Admin port
          port {
            name           = "admin"
            container_port = 3006
            protocol       = "TCP"
          }

          # Mount PostgreSQL data volume at parent directory
          # PostgreSQL initdb fails if mount point is used directly due to lost+found directory
          # Reference: https://www.postgresql.org/docs/current/app-initdb.html
          volume_mount {
            name       = "llmgateway-data"
            mount_path = "/var/lib/postgresql"
          }

          # Liveness probe using gateway health endpoint (skips dependency checks)
          # Gateway exposes health at root path "/", not "/health"
          # Reference: https://github.com/theopenco/llmgateway/blob/main/apps/gateway/src/app.ts
          liveness_probe {
            http_get {
              path = "/?skip=redis,database"
              port = 4001 # Gateway port
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          # Readiness probe using gateway health endpoint (full health check)
          # Checks Redis and database connectivity before accepting traffic
          # Reference: https://github.com/theopenco/llmgateway/blob/main/apps/gateway/src/app.ts
          readiness_probe {
            http_get {
              path = "/"
              port = 4001 # Gateway port
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          # Startup probe allows for slow initialization (PostgreSQL, Redis, migrations)
          # Prevents liveness probe from killing pod during extended startup
          # Reference: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
          startup_probe {
            http_get {
              path = "/"
              port = 4001 # Gateway port
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 18 # 18 * 10s = 180s max startup time
          }
        }

        volume {
          name = "llmgateway-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.llmgateway_data[0].metadata[0].name
          }
        }
      }
    }
  }
}

# Service exposing LLM Gateway ports
resource "kubernetes_service_v1" "llmgateway" {
  count = var.llmgateway_enable ? 1 : 0

  metadata {
    name      = "llmgateway"
    namespace = kubernetes_namespace.llmgateway[0].metadata[0].name
  }

  spec {
    selector = {
      app = "llmgateway"
    }

    type = "ClusterIP"

    # Web UI
    port {
      name        = "ui"
      port        = 3002
      target_port = 3002
      protocol    = "TCP"
    }

    # API
    port {
      name        = "api"
      port        = 4002
      target_port = 4002
      protocol    = "TCP"
    }

    # Gateway (OpenAI compatible)
    port {
      name        = "gateway"
      port        = 4001
      target_port = 4001
      protocol    = "TCP"
    }

    # Admin
    port {
      name        = "admin"
      port        = 3006
      target_port = 3006
      protocol    = "TCP"
    }

    # Note: Documentation port (3005) and Playground (3003) intentionally not exposed
  }
}
