# Requirements only. The module inherits the root's configured `oci` provider, which is
# what allows one configuration to serve any number of accounts.
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.25"
    }
  }
}
