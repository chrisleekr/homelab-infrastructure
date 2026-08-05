# One block per account, not a for_each over the account map. A module call using count or
# for_each cannot pass a different provider configuration to each instance:
# https://developer.hashicorp.com/terraform/language/modules/develop/providers
#
# One module per account rather than per node: the VCN, NSG and quota are shared by every
# node in the account, and the module for_each'es the nodes internally.
#
# No count, because account1 is required. Adding account2 is a copy of this block and its
# provider alias, gated on `lookup(var.stage0_oci_accounts, "account2", null) != null`,
# plus one more argument in outputs.tf.
module "oci_freetier_account1" {
  source = "./oci-freetier"

  providers = {
    oci = oci.oci_freetier_account1
  }

  tenancy_ocid       = var.stage0_oci_accounts["account1"].tenancy_ocid
  compartment_ocid   = var.stage0_oci_accounts["account1"].compartment_ocid
  nodes              = var.stage0_oci_accounts["account1"].nodes
  ssh_public_key     = var.stage0_ssh_public_key
  tailscale_auth_key = var.stage0_tailscale_auth_key
  ssh_ingress_cidrs  = var.stage0_ssh_ingress_cidrs
  budget_enable      = var.stage0_budget_enable
}
