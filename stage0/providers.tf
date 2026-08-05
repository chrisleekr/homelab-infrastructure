terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.25"
    }
  }
}

# Aliased despite there being one account today: an unaliased default is inherited by every
# module, so account2 would mean converting this block rather than copying it.
#
# Indexed directly, with no try() fallback. account1 is required by the validation on
# stage0_oci_accounts, so the missing case is rejected before this block is evaluated.
provider "oci" {
  alias = "oci_freetier_account1"

  tenancy_ocid = var.stage0_oci_accounts["account1"].tenancy_ocid
  user_ocid    = var.stage0_oci_accounts["account1"].user_ocid
  fingerprint  = var.stage0_oci_accounts["account1"].fingerprint
  region       = var.stage0_oci_accounts["account1"].region
  private_key  = var.stage0_oci_private_keys["account1"]
}
