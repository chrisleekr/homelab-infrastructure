# Shared identifiers for the OmniRoute module.
#
# Every name below is referenced from more than one place. Centralising them keeps the Ingress
# backends, the Helm values, and the outputs from drifting apart: a wrong Service name produces a
# 503 at runtime with no Terraform error at all.

locals {
  # Empty string while disabled: the namespace resource has count = 0, so indexing it is invalid.
  omniroute_namespace = var.omniroute_enable ? kubernetes_namespace_v1.omniroute[0].metadata[0].name : ""

  # Pinned via fullnameOverride in the values template. Without the override the chart derives the
  # Service name from the Helm release name, silently coupling the Ingress backend to it.
  omniroute_service_name = "omniroute"
  omniroute_service_port = 20128

  omniroute_scheme = var.omniroute_ingress_enable_tls ? "https" : "http"

  # Shared by both Ingresses. cert-manager is annotated on exactly one of them (the UI, see
  # ingress.tf).
  omniroute_tls_secret_name = "omniroute-tls"

  # Module-owned Secret holding the 4 auth keys, referenced by the chart via auth.existingSecret.
  omniroute_auth_secret_name = "omniroute-auth"

  # Every prefix that reaches /api/v1 handlers with an arbitrary trailing path, read from the image's
  # next.config.mjs rewrites(). NOT var.omniroute_public_paths: the app aliases more prefixes than
  # the Ingress opens.
  #
  # /v1/v1 is the trap: not opened by the API Ingress, so nginx has no location for it and its
  # longest match is the OPEN /v1/ location. Ungated admin routes unless listed here. Re-read
  # rewrites() on every image bump.
  omniroute_api_alias_prefixes = ["/api/v1", "/v1", "/v1/v1"]

  # Crossed rather than listed literally so a suffix cannot be added for one alias and missed on
  # another.
  omniroute_gated_admin_paths = distinct(flatten([
    for prefix in local.omniroute_api_alias_prefixes : [
      for suffix in var.omniroute_gated_admin_suffixes : "${prefix}${suffix}"
    ]
  ]))

  # Request-size and timeout annotations both Ingresses need. Held here so the two cannot drift
  # apart; the security-bearing annotations stay inline at each resource where they are audited.
  omniroute_ingress_base_annotations = {
    "nginx.ingress.kubernetes.io/proxy-body-size"    = "50m"
    "nginx.ingress.kubernetes.io/proxy-read-timeout" = "600"
    "nginx.ingress.kubernetes.io/proxy-send-timeout" = "600"
  }
}
