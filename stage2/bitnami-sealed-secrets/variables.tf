variable "sealed_secrets_key_renewal_period" {
  description = "Key renewal period for the sealed-secrets controller (default 720h = 30 days)"
  type        = string
  default     = "720h"
}
