# The 4 auth credentials are created by Terraform from bws-injected TF_VAR_* values and referenced
# by name from the Helm chart via auth.existingSecret, so no credential is ever written into the
# Helm values string (and therefore never into the Helm release secret). A non-empty existingSecret
# also makes the chart skip its own secret.yaml, which would otherwise mint fresh
# JWT_SECRET / API_KEY_SECRET on every client-side render.
#
# Credential rules are enforced in two layers. The `validation` blocks in variables.tf carry a
# `== ""` escape hatch so the empty defaults stay valid while the module is disabled; they catch a
# malformed value the moment one is supplied. The `precondition` blocks below have no escape hatch
# but only evaluate when count = 1, so they are what makes each key mandatory once the module is
# actually enabled.
#
# WRITE ONCE: API_KEY_SECRET encrypts stored provider API keys and STORAGE_ENCRYPTION_KEY encrypts
# the database at rest. Rotating either makes already-stored data permanently unreadable. JWT_SECRET
# only signs dashboard sessions and can be rotated (it just logs everyone out).
resource "kubernetes_secret_v1" "auth" {
  count = var.omniroute_enable ? 1 : 0

  metadata {
    name      = "omniroute-auth"
    namespace = local.omniroute_namespace
  }

  data = {
    JWT_SECRET             = var.omniroute_jwt_secret
    API_KEY_SECRET         = var.omniroute_api_key_secret
    INITIAL_PASSWORD       = var.omniroute_initial_password
    STORAGE_ENCRYPTION_KEY = var.omniroute_storage_encryption_key
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]

    precondition {
      condition     = length(var.omniroute_jwt_secret) >= 32
      error_message = "omniroute_jwt_secret must be at least 32 characters when omniroute_enable is true. Generate with: openssl rand -hex 32"
    }

    precondition {
      condition     = length(var.omniroute_api_key_secret) >= 32
      error_message = "omniroute_api_key_secret must be at least 32 characters when omniroute_enable is true. WRITE ONCE: rotating it makes stored provider keys unreadable. Generate with: openssl rand -hex 32"
    }

    precondition {
      condition     = length(var.omniroute_initial_password) >= 12
      error_message = "omniroute_initial_password must be at least 12 characters when omniroute_enable is true. Change it from the dashboard after first login."
    }

    precondition {
      condition     = length(var.omniroute_storage_encryption_key) >= 32
      error_message = "omniroute_storage_encryption_key must be at least 32 characters when omniroute_enable is true. WRITE ONCE: rotating it makes the encrypted database unreadable. Generate with: openssl rand -hex 32"
    }
  }
}
