# Input variables for the LiteLLM module.
#
# Secret-bearing variables default to "" so the module stays valid while disabled. Their real
# constraints are enforced by `precondition` blocks in secrets.tf, which only evaluate when the
# module is enabled.

variable "litellm_enable" {
  description = "Enable the LiteLLM proxy deployment"
  type        = bool
  default     = false
}

variable "litellm_domain" {
  description = "Domain name for the LiteLLM ingress. Both the API and the admin UI are served from this single host"
  type        = string
  default     = "litellm.chrislee.local"
}

variable "litellm_ingress_class_name" {
  description = "Ingress class name for the LiteLLM ingresses"
  type        = string
  default     = "nginx"
}

variable "litellm_ingress_enable_tls" {
  description = "Enable TLS on the LiteLLM ingresses. When true, cert-manager issues litellm-tls from the letsencrypt-prod ClusterIssuer"
  type        = bool
  default     = true
}

variable "litellm_ui_paths" {
  description = "URL path prefixes routed to the oauth2-proxy protected ingress. /litellm-asset-prefix serves the console JS and CSS, and /fallback/login plus /login are the console's login page and its credential POST target. /docs, /redoc, /openapi.json, /routes, /config/yaml and /public are introspection surfaces no API client needs. Anything omitted here falls through to the unauthenticated API ingress"
  type        = list(string)
  default = [
    "/ui", "/sso", "/litellm-asset-prefix",
    # The console's login page and the endpoint its form POSTs to, both reachable without
    # credentials. Omitting them leaves the whole login flow outside the gate.
    "/fallback/login", "/login",
    # Introspection surfaces. NO_DOCS alone only removes /docs; /openapi.json still serves the full
    # schema and /redoc renders it. /.well-known is left ungated so cert-manager's HTTP-01 solver
    # stays reachable; the only LiteLLM route under it is /.well-known/litellm-ui-config, which was
    # measured returning UI routing metadata only (server_root_path, sso_configured and similar),
    # no credentials, so there is nothing there worth gating.
    "/docs", "/redoc", "/openapi.json", "/routes",
    # LiteLLM's own unauthenticated allow-list (LiteLLMRoutes.public_routes). /config/yaml returns
    # the proxy config and /public/* the model, agent, mcp and skill hubs, so both disclose which
    # providers hold keys here. No OpenAI-SDK client requests either. /health/* stays ungated for
    # probes and external monitoring.
    # Ref: https://github.com/BerriAI/litellm/blob/v1.89.2/litellm/proxy/_types.py
    "/config/yaml", "/public",
  ]

  validation {
    condition     = length(var.litellm_ui_paths) > 0
    error_message = "litellm_ui_paths must contain at least one path"
  }
}

variable "litellm_chart_version" {
  description = "litellm-helm chart version. The chart version tracks appVersion, so bump it together with litellm_image_tag. Reference: https://github.com/BerriAI/litellm/tree/main/deploy/charts/litellm-helm"
  type        = string
  default     = "1.89.2"
}

variable "litellm_image_tag" {
  description = "Tag for ghcr.io/berriai/litellm-database. No 'v' prefix: the chart's own default is the bare appVersion"
  type        = string
  default     = "1.89.2"
}

variable "litellm_postgres_image_tag" {
  description = "Tag for the upstream postgres image backing LiteLLM. Must be an -alpine tag: the StatefulSet sets fs_group = 70, which is the alpine postgres gid (the Debian variant uses 999)"
  type        = string
  default     = "18.4-alpine"

  validation {
    condition     = var.litellm_postgres_image_tag != "latest" && endswith(var.litellm_postgres_image_tag, "-alpine")
    error_message = "litellm_postgres_image_tag must be a pinned -alpine tag: the StatefulSet sets fs_group = 70, the alpine postgres gid (Debian images use 999)"
  }
}

variable "litellm_replicas" {
  description = "Number of LiteLLM proxy replicas"
  type        = number
  default     = 1

  validation {
    condition     = var.litellm_replicas >= 1
    error_message = "litellm_replicas must be at least 1"
  }
}

variable "litellm_storage_class_name" {
  description = "Storage class name for the LiteLLM Postgres persistent volume"
  type        = string
  default     = "longhorn"
}

variable "litellm_storage_size" {
  description = "Storage size for the LiteLLM Postgres persistent volume"
  type        = string
  default     = "10Gi"

  # Validate Kubernetes storage size format per Kubernetes quantity spec
  # Ref: https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/quantity/
  validation {
    condition     = can(regex("^([0-9]+(\\.[0-9]+)?)(Ei|Pi|Ti|Gi|Mi|Ki|E|P|T|G|M|K)$", var.litellm_storage_size))
    error_message = "Must be a valid Kubernetes storage size (e.g., 10Gi, 1.5Ti, 500Mi)"
  }
}

variable "litellm_master_key" {
  description = "LiteLLM admin and API superuser key, injected as PROXY_MASTER_KEY. Generate with: echo \"sk-$(openssl rand -hex 24)\""
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.litellm_master_key == "" || startswith(var.litellm_master_key, "sk-")
    error_message = "litellm_master_key must start with 'sk-'"
  }
}

variable "litellm_salt_key" {
  description = "Encrypts provider credentials stored in the database. WRITE ONCE: rotating it makes every stored credential permanently unreadable. Generate with: echo \"sk-$(openssl rand -hex 24)\""
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.litellm_salt_key == "" || startswith(var.litellm_salt_key, "sk-")
    error_message = "litellm_salt_key must start with 'sk-'"
  }
}

variable "litellm_db_password" {
  description = "Password for the module-owned Postgres. Restricted to URI-safe characters: the chart builds db.url as postgresql://user:password@host/db, and a reserved character would silently corrupt it. Generate with: openssl rand -hex 16"
  type        = string
  sensitive   = true
  default     = ""

  # Reserved URI characters (@ : / ? # %) would re-parse the connection string into a different
  # host or database rather than fail loudly. Postgres requires them percent-encoded in a URI.
  # Ref: https://www.postgresql.org/docs/current/libpq-connect.html
  validation {
    condition = var.litellm_db_password == "" || (
      length(var.litellm_db_password) >= 16 &&
      can(regex("^[A-Za-z0-9_.~-]+$", var.litellm_db_password))
    )
    error_message = "litellm_db_password must be at least 16 characters using only A-Z a-z 0-9 _ . ~ - (it is interpolated into a postgresql:// URI). Generate with: openssl rand -hex 16"
  }
}

variable "litellm_provider_secrets" {
  description = "Upstream provider API keys, delivered as one JSON object and exported to the pod as environment variables. proxy_config references them as os.environ/<KEY>. Adding a provider needs no Terraform change"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "auth_oauth2_proxy_host" {
  description = "Hostname of the oauth2-proxy instance guarding the LiteLLM admin console"
  type        = string
  default     = ""
}
