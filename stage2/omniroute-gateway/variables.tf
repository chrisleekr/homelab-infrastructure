# Input variables for the OmniRoute module.
#
# Secret-bearing variables default to "" so the module stays valid while disabled. Their real
# constraints are enforced by `precondition` blocks in secrets.tf, which only evaluate when the
# module is enabled.

variable "omniroute_enable" {
  description = "Enable the OmniRoute AI gateway deployment"
  type        = bool
  default     = false
}

variable "omniroute_domain" {
  description = "Domain name for the OmniRoute ingress. Both the open API surface (/v1 and /api/v1) and the gated dashboard are served from this single host"
  type        = string
  default     = "omniroute.chrislee.local"
}

variable "omniroute_ingress_class_name" {
  description = "Ingress class name for the OmniRoute ingresses"
  type        = string
  default     = "nginx"
}

variable "omniroute_ingress_enable_tls" {
  description = "Enable TLS on the OmniRoute ingresses. When true, cert-manager issues omniroute-tls from the letsencrypt-prod ClusterIssuer, annotated on the UI ingress only"
  type        = bool
  default     = true
}

variable "omniroute_public_paths" {
  description = "URL path prefixes routed to the open, unauthenticated API ingress. Everything else falls through to the oauth2-proxy-gated ingress. Defaults to both OpenAI-compatible base paths, which are the same handler. Provider OAuth/webhook callbacks and cert-manager's /.well-known are opt-in additions; re-verify against a running container"
  type        = list(string)
  default     = ["/api/v1", "/v1"]

  validation {
    condition     = length(var.omniroute_public_paths) > 0
    error_message = "omniroute_public_paths must contain at least one path"
  }

  # Concatenated with the admin suffixes in locals.tf. A malformed prefix yields a gate location no
  # request can ever match, which fails open silently. Caught at plan time because the open Ingress
  # applies first: a late failure widens the open surface while leaving the gate unchanged.
  validation {
    condition = alltrue([
      for path in var.omniroute_public_paths :
      startswith(path, "/") && !endswith(path, "/") && !strcontains(path, "//")
    ])
    error_message = "Every omniroute_public_paths entry must start with \"/\", must not end with \"/\", and must not contain \"//\"."
  }
}

variable "omniroute_gated_admin_suffixes" {
  description = "Admin route suffixes pulled back behind oauth2-proxy as defense in depth, applied to every API alias prefix in locals.tf. OpenAI-compatible clients never call these, so gating them costs model traffic nothing. Suffixes rather than full paths because several prefixes rewrite onto the same handlers, so every alias must carry the gate. Set to [] to disable; re-verify against a running container"
  type        = list(string)
  default = [
    "/management",
    "/agents",
    "/accounts",
    "/registered-keys",
  ]

  # Same shape rules as omniroute_public_paths, same reason.
  validation {
    condition = alltrue([
      for suffix in var.omniroute_gated_admin_suffixes :
      startswith(suffix, "/") && !endswith(suffix, "/") && length(suffix) > 1 && !strcontains(suffix, "//")
    ])
    error_message = "Every omniroute_gated_admin_suffixes entry must start with \"/\", must not end with \"/\", must not contain \"//\", and must be longer than \"/\": suffixes are concatenated onto each API alias prefix."
  }
}

variable "omniroute_chart_version" {
  description = "omniroute Helm chart version from https://chrisleekr.github.io/helm-charts. The chart version tracks appVersion, so bump it together with omniroute_image_tag"
  type        = string
  default     = "0.1.1"
}

variable "omniroute_image_tag" {
  description = "Tag for diegosouzapw/omniroute. Empty defaults to the chart appVersion. Use the -web flavor (e.g. 3.8.48-web) for web-cookie providers like gemini-web or claude-web"
  type        = string
  default     = ""
}

variable "omniroute_storage_class_name" {
  description = "Storage class name for the OmniRoute SQLite persistent volume"
  type        = string
  default     = "longhorn"
}

variable "omniroute_storage_size" {
  description = "Storage size for the OmniRoute SQLite persistent volume"
  type        = string
  default     = "5Gi"

  # Validate Kubernetes storage size format per Kubernetes quantity spec
  # Ref: https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/quantity/
  validation {
    condition     = can(regex("^([0-9]+(\\.[0-9]+)?)(Ei|Pi|Ti|Gi|Mi|Ki|E|P|T|G|M|K)$", var.omniroute_storage_size))
    error_message = "Must be a valid Kubernetes storage size (e.g., 5Gi, 1.5Ti, 500Mi)"
  }
}

variable "omniroute_initial_password" {
  description = "Initial dashboard admin password, injected as INITIAL_PASSWORD. Only used on first boot; change it from the dashboard afterwards. Generate with: openssl rand -base64 24"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.omniroute_initial_password == "" || length(var.omniroute_initial_password) >= 12
    error_message = "omniroute_initial_password must be at least 12 characters"
  }
}

variable "omniroute_jwt_secret" {
  description = "Signs dashboard session tokens, injected as JWT_SECRET. Rotatable: rotating only logs users out. Generate with: openssl rand -hex 32"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.omniroute_jwt_secret == "" || length(var.omniroute_jwt_secret) >= 32
    error_message = "omniroute_jwt_secret must be at least 32 characters"
  }
}

variable "omniroute_api_key_secret" {
  description = "Encrypts stored provider API keys, injected as API_KEY_SECRET. WRITE ONCE: rotating it makes every stored provider key permanently unreadable. Generate with: openssl rand -hex 32"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.omniroute_api_key_secret == "" || length(var.omniroute_api_key_secret) >= 32
    error_message = "omniroute_api_key_secret must be at least 32 characters"
  }
}

variable "omniroute_storage_encryption_key" {
  description = "Encrypts the OmniRoute database at rest, injected as STORAGE_ENCRYPTION_KEY. WRITE ONCE: rotating it makes an already-encrypted database unreadable. Generate with: openssl rand -hex 32"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.omniroute_storage_encryption_key == "" || length(var.omniroute_storage_encryption_key) >= 32
    error_message = "omniroute_storage_encryption_key must be at least 32 characters"
  }
}

variable "auth_oauth2_proxy_host" {
  description = "Hostname of the oauth2-proxy instance guarding the OmniRoute dashboard"
  type        = string
  default     = ""
}
