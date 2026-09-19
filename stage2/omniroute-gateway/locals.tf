# Shared identifiers for the OmniRoute module.
#
# Every name below is referenced from more than one place. Centralising them keeps the route
# backend, the Helm values, and the outputs from drifting apart: a wrong Service name produces a
# 503 at runtime with no Terraform error at all.

locals {
  # Empty string while disabled: the namespace resource has count = 0, so indexing it is invalid.
  omniroute_namespace = var.omniroute_enable ? kubernetes_namespace_v1.omniroute[0].metadata[0].name : ""

  # Pinned via fullnameOverride in the values template. Without the override the chart derives the
  # Service name from the Helm release name, silently coupling the route backend to it.
  omniroute_service_name = "omniroute"
  omniroute_service_port = 20128

  # Named by both the ListenerSet certificateRef and the Certificate in httproute.tf.
  omniroute_tls_secret_name = "omniroute-tls"

  # Module-owned Secret holding the 4 auth keys, referenced by the chart via auth.existingSecret.
  omniroute_auth_secret_name = "omniroute-auth"

  # Every prefix the image rewrites onto /api/v1 handlers, read from its next.config.mjs rewrites().
  # Deliberately wider than var.omniroute_public_paths: an alias that is not opened still reaches
  # the handler via the open prefix, so it needs a gate entry. /v1/v1 is that case. Re-read
  # rewrites() on every image bump.
  omniroute_api_alias_prefixes = ["/api/v1", "/v1", "/v1/v1"]

  # Crossed rather than listed literally so a suffix cannot be added for one alias and missed on
  # another.
  omniroute_gated_admin_paths = distinct(flatten([
    for prefix in local.omniroute_api_alias_prefixes : [
      for suffix in var.omniroute_gated_admin_suffixes : "${prefix}${suffix}"
    ]
  ]))

}
