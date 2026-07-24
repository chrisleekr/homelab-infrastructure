# Shared identifiers for the LiteLLM module.
#
# Every name below is referenced from more than one place. Centralising them keeps the Ingress
# backends, the Helm values, the Postgres probes, and the outputs from drifting apart: a wrong
# Service name produces a 503 at runtime with no Terraform error at all.

locals {
  # Empty string while disabled: the namespace resource has count = 0, so indexing it is invalid.
  litellm_namespace = var.litellm_enable ? kubernetes_namespace_v1.litellm[0].metadata[0].name : ""

  # Pinned via fullnameOverride in the values template. Without the override the chart derives the
  # Service name from the Helm release name, silently coupling the Ingress backend to it.
  litellm_service_name = "litellm"
  litellm_service_port = 4000

  # Used by the Postgres container env, all three pg_isready probes, and the litellm-db Secret.
  litellm_db_username = "litellm"
  litellm_db_name     = "litellm"

  litellm_scheme = var.litellm_ingress_enable_tls ? "https" : "http"

  # Shared by both Ingresses. cert-manager is annotated on exactly one of them (see ingress.tf).
  litellm_tls_secret_name = "litellm-tls"

  # Request-size and timeout annotations both Ingresses need. Held here so the two cannot drift
  # apart; the security-bearing annotations stay inline at each resource where they are audited.
  litellm_ingress_base_annotations = {
    "nginx.ingress.kubernetes.io/proxy-body-size"    = "50m"
    "nginx.ingress.kubernetes.io/proxy-read-timeout" = "600"
    "nginx.ingress.kubernetes.io/proxy-send-timeout" = "600"
  }

  # Shared by the startup, readiness and liveness probes. -h 127.0.0.1 forces a TCP check: during
  # init postgres briefly accepts local socket connections before it is ready to serve real traffic.
  litellm_pg_isready_command = [
    "pg_isready", "-h", "127.0.0.1",
    "-U", local.litellm_db_username,
    "-d", local.litellm_db_name,
  ]
}
