# One map per provider, keyed by account label, so `bws run` injects a single secret
# covering every OCI account and one apply provisions all of them. Each key is wired by
# hand to a provider alias and a module block, because provider configuration cannot be
# iterated. Not provider-agnostic on purpose: the credential triple and the A1 shape config
# under `nodes` are both OCI-only, and map(object) is a closed type.
#
# No default. stage0 is a separate root you only run to create cloud nodes, and a default
# would let a failed secret injection apply cleanly and produce an unreachable instance:
# no SSH key with password auth off, and no tailnet address. `terraform validate` does not
# need variable values, so requiring them costs the pre-commit hook nothing.
#
# Deliberately NOT sensitive: Terraform rejects for_each derived from sensitive values,
# and `nodes` is for_each'd inside the module. OCIDs and fingerprints are identifiers,
# not secrets.
variable "stage0_oci_accounts" {
  description = "OCI accounts keyed by account label, account1 first, each carrying its node list."
  type = map(object({
    region       = string
    tenancy_ocid = string
    user_ocid    = string
    fingerprint  = string
    # Created during account setup, not by this configuration. See the module variable of
    # the same name for why Terraform cannot be what creates it.
    compartment_ocid = string
    nodes = map(object({
      # OCPUs, not vCPUs. It is OCI's unit, what shape_config takes, and what the Always
      # Free allowance is quoted in.
      ocpus         = optional(number, 2)
      memory_gbs    = optional(number, 12)
      boot_disk_gbs = optional(number, 100)
    }))
  }))

  # account1 is the required one, so a typo in the top-level key fails here with a readable
  # message rather than "Invalid index" from the provider block. Later accounts are optional.
  validation {
    condition     = contains(keys(var.stage0_oci_accounts), "account1")
    error_message = "stage0_oci_accounts must contain an account1 entry. Check the TF_VAR_stage0_oci_accounts secret."
  }
}

variable "stage0_oci_private_keys" {
  description = "OCI API signing private keys in PEM form, keyed by the same account labels."
  type        = map(string)
  sensitive   = true

  validation {
    condition     = contains(keys(var.stage0_oci_private_keys), "account1")
    error_message = "stage0_oci_private_keys must contain an account1 entry. Check the TF_VAR_stage0_oci_private_keys secret."
  }
}

# Both validations reject "" as well as unset. A secret that exists but injected empty would
# otherwise apply cleanly and produce an unreachable instance: no SSH key with password auth
# off, and no tailnet address.
variable "stage0_ssh_public_key" {
  description = "SSH public key injected into every provisioned node for the ubuntu user."
  type        = string

  validation {
    condition     = var.stage0_ssh_public_key != ""
    error_message = "stage0_ssh_public_key is empty. Set the TF_VAR_stage0_ssh_public_key secret before provisioning."
  }
}

variable "stage0_tailscale_auth_key" {
  description = "Pre-authorized, short-expiry Tailscale auth key used once by cloud-init."
  type        = string
  sensitive   = true

  validation {
    condition     = var.stage0_tailscale_auth_key != ""
    error_message = "stage0_tailscale_auth_key is empty. Generate a key tagged tag:k8s-node before provisioning."
  }
}

# A CIDR list rather than a bool: a boolean invites 0.0.0.0/0. Empty creates no rule,
# which is the normal state since Ansible arrives over the tailnet.
variable "stage0_ssh_ingress_cidrs" {
  description = "Source CIDRs permitted to reach port 22 from the internet. Empty creates no rule."
  type        = list(string)
  default     = []

  # A prefix floor rather than a literal 0.0.0.0/0 compare: the string test misses the
  # equivalent spellings, 0.0.0.0/1 plus 128.0.0.0/1 among them. can(cidrnetmask())
  # also rejects anything that is not a CIDR, which matters because these values are
  # interpolated into a shell command in cloud-init.
  validation {
    condition = alltrue([
      for c in var.stage0_ssh_ingress_cidrs :
      can(cidrnetmask(c)) && tonumber(split("/", c)[1]) >= 24
    ])
    error_message = "Each entry must be a valid IPv4 CIDR of /24 or narrower. SSH reaches these nodes over the tailnet; this list is a break-glass hatch for named sources only."
  }
}

variable "stage0_budget_enable" {
  description = "Create cloud budget resources. Meaningless on an unupgraded Always Free account, which cannot be charged."
  type        = bool
  default     = false
}
