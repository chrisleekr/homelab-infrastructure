# Quotas hard-block creation rather than alerting after the fact, which is the right
# guard for an account that must never generate a bill.
#
# All three quotas are scoped per availability domain, not per tenancy
# (https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/resourcequotas_topic-Compute_Quotas.htm
# and .../resourcequotas_topic-Block_Volume_Quotas.htm). In a multi-AD region the effective
# ceiling is therefore the value below times the AD count, which is looser than the Always
# Free allowance. terraform_data.freetier_guard is what actually enforces the tenancy-wide
# sum; these are the backstop against anything created outside Terraform.
#
# Memory lives in its own `compute-memory` family, not in `compute-core`.

# Quota statements identify the compartment by name, not by OCID.
data "oci_identity_compartment" "homelab" {
  id = var.compartment_ocid
}

resource "oci_limits_quota" "freetier_ceiling" {
  compartment_id = var.tenancy_ocid
  name           = "homelab-freetier-ceiling"
  description    = "Caps the homelab compartment at the Always Free allowance."

  statements = [
    "set compute-core quota standard-a1-core-count to ${local.always_free.a1_max_ocpus} in compartment ${data.oci_identity_compartment.homelab.name}",
    "set compute-memory quota standard-a1-memory-count to ${local.always_free.a1_max_memory_gbs} in compartment ${data.oci_identity_compartment.homelab.name}",
    "set block-storage quota total-storage-gb to ${local.always_free.storage_max_gbs} in compartment ${data.oci_identity_compartment.homelab.name}",
  ]
}

# Off by default. An unupgraded Always Free account has no payment method, so it cannot
# be charged and a budget alert is decoration. Real only after a PAYG upgrade.
resource "oci_budget_budget" "homelab" {
  count = var.budget_enable ? 1 : 0

  compartment_id = var.tenancy_ocid
  target_type    = "COMPARTMENT"
  targets        = [var.compartment_ocid]
  reset_period   = "MONTHLY"
  amount         = 1
  display_name   = "homelab-freetier"
}
