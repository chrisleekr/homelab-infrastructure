variable "tenancy_ocid" {
  description = "Tenancy OCID. Quotas, budgets and availability domains are tenancy-level, so they are addressed against this rather than the homelab compartment."
  type        = string
}

# An input rather than a resource here. The IAM policy that authorizes this module names the
# compartment, and OCI rejects a policy statement referencing a compartment that does not yet
# exist, so it has to be created during account setup. That also keeps the Terraform user's
# compartment grant at `inspect`, with no create or delete rights anywhere in the tenancy.
variable "compartment_ocid" {
  description = "OCID of the homelab compartment. Everything this module creates lives inside it."
  type        = string
}

# Mirrors the nodes type in the root stage0_oci_accounts variable, without optional():
# the root applies its defaults during type conversion, so what arrives here is complete.
variable "nodes" {
  description = "Nodes to provision in this account, keyed by name. The key becomes the instance display name, the VNIC hostname label and the Tailscale hostname."
  type = map(object({
    ocpus         = number
    memory_gbs    = number
    boot_disk_gbs = number
  }))
}

variable "ssh_public_key" {
  description = "SSH public key injected into every node for the ubuntu user."
  type        = string
}

variable "tailscale_auth_key" {
  description = "Pre-authorized Tailscale auth key, consumed once by cloud-init."
  type        = string
  sensitive   = true
}

# Mirrors the root validation. Terraform validates where a variable is declared, not
# where the value travels, so the module needs its own copy to hold the invariant for
# any future caller.
variable "ssh_ingress_cidrs" {
  description = "Source CIDRs permitted to reach port 22 from the internet. Empty creates no rule."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for c in var.ssh_ingress_cidrs :
      can(cidrnetmask(c)) && tonumber(split("/", c)[1]) >= 24
    ])
    error_message = "Each entry must be a valid IPv4 CIDR of /24 or narrower."
  }
}

variable "budget_enable" {
  description = "Create the budget resource."
  type        = bool
  default     = false
}
