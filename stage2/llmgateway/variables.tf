# Input variables for LLM Gateway module

variable "llmgateway_enable" {
  description = "Enable LLM Gateway deployment"
  type        = bool
  default     = false
}

variable "llmgateway_domain" {
  description = "Domain name for LLM Gateway ingress"
  type        = string
  default     = "llm.chrislee.local"
}

variable "llmgateway_ingress_class_name" {
  description = "Ingress class name for LLM Gateway"
  type        = string
  default     = "nginx"
}

variable "llmgateway_ingress_enable_tls" {
  description = "Enable TLS for LLM Gateway ingress"
  type        = bool
  default     = true
}

variable "llmgateway_storage_size" {
  description = "Storage size for PostgreSQL data persistence"
  type        = string
  default     = "10Gi"
}

variable "llmgateway_storage_class_name" {
  description = "Storage class name for persistent volume"
  type        = string
  default     = "longhorn"
}

variable "llmgateway_auth_secret" {
  description = "AUTH_SECRET for LLM Gateway session management. Generate with: openssl rand -hex 32"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    # Validate length only when a non-empty value is provided
    # Empty value is allowed when module is disabled (count = 0)
    condition     = var.llmgateway_auth_secret == "" || length(var.llmgateway_auth_secret) >= 32
    error_message = "llmgateway_auth_secret must be at least 32 characters when provided. Generate with: openssl rand -hex 32"
  }
}

variable "llmgateway_image_tag" {
  description = "Docker image tag for LLM Gateway unified image. Use specific version from https://github.com/theopenco/llmgateway/releases"
  type        = string
  default     = "latest"
}

variable "llmgateway_replicas" {
  description = "Number of LLM Gateway replicas. Note: Multiple replicas require ReadWriteMany storage or separate PVCs"
  type        = number
  default     = 1

  validation {
    condition     = var.llmgateway_replicas >= 1
    error_message = "llmgateway_replicas must be at least 1"
  }
}

# Admin emails for LLM Gateway admin dashboard access
# Reference: https://github.com/theopenco/llmgateway/blob/main/apps/api/src/routes/user.ts
variable "llmgateway_admin_emails" {
  description = "Comma-separated list of email addresses that have admin access to LLM Gateway admin dashboard"
  type        = string
  sensitive   = true
  default     = ""
}

# OAuth2 proxy host for UI authentication
# Reference: https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/
variable "auth_oauth2_proxy_host" {
  description = "OAuth2 proxy host for authentication (e.g., auth.example.com)"
  type        = string
  default     = ""
}
