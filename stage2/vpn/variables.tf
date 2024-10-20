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

variable "tailscale_hostname" {
  description = "The hostname of the tailscale"
  type        = string
  default     = "tailscale-kubernetes"
}

variable "tailscale_timezone" {
  description = "The timezone of the tailscale"
  type        = string
  default     = "Australia/Melbourne"
}
