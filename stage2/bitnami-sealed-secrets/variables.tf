variable "sealed_secrets_key_renewal_period" {
  description = "Key renewal period for the sealed-secrets controller (default 720h = 30 days)"
  type        = string
  default     = "720h"

  validation {
    condition     = can(regex("^[0-9]+(h|m|s)$", var.sealed_secrets_key_renewal_period))
    error_message = "sealed_secrets_key_renewal_period must be a Go duration string, e.g. '720h', '30m', '3600s'."
  }
}
