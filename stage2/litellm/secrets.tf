# All three secrets are created by Terraform from bws-injected TF_VAR_* values and referenced by
# name from the Helm chart, so no credential is ever written into the Helm values string (and
# therefore never into the Helm release secret).
#
# Credential rules are enforced in two layers. The `validation` blocks in variables.tf carry an
# `== ""` escape hatch so the empty defaults stay valid while the module is disabled; they catch a
# malformed value the moment one is supplied. The `precondition` blocks below have no such escape
# hatch, but only evaluate when count = 1, so they are what makes a value mandatory once the module
# is actually enabled.

# Chart injects this as env PROXY_MASTER_KEY via masterkeySecretName / masterkeySecretKey.
resource "kubernetes_secret_v1" "masterkey" {
  count = var.litellm_enable ? 1 : 0

  metadata {
    name      = "litellm-masterkey"
    namespace = local.litellm_namespace
  }

  data = {
    masterkey = var.litellm_master_key
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]

    precondition {
      condition     = startswith(var.litellm_master_key, "sk-")
      error_message = "litellm_master_key must start with 'sk-' when litellm_enable is true. Generate with: echo \"sk-$(openssl rand -hex 24)\""
    }
  }
}

# Salt key plus every provider API key, exported to the pod via envFrom.
#
# LITELLM_SALT_KEY encrypts provider credentials stored in the database. Changing it after models
# have been added makes those rows permanently unreadable, so treat it as write-once.
#
# Merge order is deliberate: the dedicated variable is applied LAST so it wins. Reversed, a
# LITELLM_SALT_KEY key inside the provider-secrets JSON would silently shadow it and bypass the
# 'sk-' precondition below.
resource "kubernetes_secret_v1" "env" {
  count = var.litellm_enable ? 1 : 0

  metadata {
    name      = "litellm-env"
    namespace = local.litellm_namespace
  }

  data = merge(
    var.litellm_provider_secrets,
    { LITELLM_SALT_KEY = var.litellm_salt_key },
  )

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]

    precondition {
      condition     = startswith(var.litellm_salt_key, "sk-")
      error_message = "litellm_salt_key must start with 'sk-' when litellm_enable is true. Generate once and never rotate: echo \"sk-$(openssl rand -hex 24)\""
    }
  }
}

# Postgres credentials. Consumed by the postgres container, the LiteLLM deployment, and the Prisma
# migrations Job, all by name via secretKeyRef.
resource "kubernetes_secret_v1" "db" {
  count = var.litellm_enable ? 1 : 0

  metadata {
    name      = "litellm-db"
    namespace = local.litellm_namespace
  }

  data = {
    username = local.litellm_db_username
    password = var.litellm_db_password
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]

    precondition {
      condition     = length(var.litellm_db_password) >= 16
      error_message = "litellm_db_password must be at least 16 characters when litellm_enable is true. Generate with: openssl rand -hex 16"
    }
  }
}
