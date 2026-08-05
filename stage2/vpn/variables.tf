variable "tailscale_enable" {
  description = "Enable the tailscale"
  type        = bool
  default     = false
}

variable "tailscale_auth_key" {
  description = "The auth key for the tailscale"
  type        = string
  sensitive   = true
}

variable "tailscale_advertise_routes" {
  description = "The routes to advertise to the tailscale. Comma separated. i.e. 192.86.0.0/24,192.86.1.0/24"
  type        = string
  default     = "192.168.0.0/24"
}

# Shared with stage0 and stage1 so every device this homelab owns sorts together in the
# tailnet. The separator is supplied by the template, not the value, so a prefix missing its
# trailing dash cannot silently produce "homelabgateway".
variable "hostname_prefix" {
  description = "Prefix for tailnet machine names, without a trailing dash."
  type        = string
  default     = "homelab"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.hostname_prefix))
    error_message = "hostname_prefix must be lowercase alphanumeric with optional inner dashes, and no trailing dash."
  }
}

variable "tailscale_timezone" {
  description = "The timezone of the tailscale"
  type        = string
  default     = "Australia/Melbourne"
}

variable "wireguard_enable" {
  description = "Enable the wireguard"
  type        = bool
  default     = false
}

variable "wireguard_ingress_host" {
  description = "The host for the wireguard ingress"
  type        = string
  default     = "wireguard.chrislee.local"
}

variable "wireguard_timezone" {
  description = "The timezone for the wireguard"
  type        = string
  default     = "Australia/Melbourne"
}

variable "wireguard_port" {
  description = "The port for the wireguard"
  type        = string
  default     = "51820"
}

variable "wireguard_peers" {
  description = "The number of peers for the wireguard"
  type        = number
  default     = 3
}
