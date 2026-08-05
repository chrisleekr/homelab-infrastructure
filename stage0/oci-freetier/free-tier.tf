# The allowance is per tenancy, so every check is on the sum across the account rather
# than on one node in isolation.

locals {
  # https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
  # Halved on 2026-06-15 from 4 OCPUs / 24 GB without announcement. Re-check before
  # assuming any of these still hold.
  always_free = {
    a1_max_ocpus      = 2  # 1,500 OCPU hours/month
    a1_max_memory_gbs = 12 # 9,000 GB hours/month
    min_boot_gbs      = 47
    storage_max_gbs   = 200 # boot + block combined, tenancy-wide
  }

  # Seeded with 0 because sum() errors on an empty list, and nodes = {} is legitimate:
  # it stands the account-level resources up without instances, or tears the last one down.
  total_ocpus   = sum(concat([0], [for n in var.nodes : n.ocpus]))
  total_memory  = sum(concat([0], [for n in var.nodes : n.memory_gbs]))
  total_storage = sum(concat([0], [for n in var.nodes : n.boot_disk_gbs]))
}

# A separate guard rather than preconditions on the instance: these are aggregates, so
# attaching them to a for_each'd resource would report the same failure once per node.
# The quotas in quota.tf are per availability domain and cannot express this sum.
resource "terraform_data" "freetier_guard" {
  lifecycle {
    precondition {
      condition     = local.total_ocpus <= local.always_free.a1_max_ocpus
      error_message = "Nodes total ${local.total_ocpus} OCPUs, over the Always Free A1 allowance of ${local.always_free.a1_max_ocpus}."
    }
    precondition {
      condition     = local.total_memory <= local.always_free.a1_max_memory_gbs
      error_message = "Nodes total ${local.total_memory} GB, over the Always Free A1 allowance of ${local.always_free.a1_max_memory_gbs} GB."
    }
    precondition {
      condition     = local.total_storage <= local.always_free.storage_max_gbs
      error_message = "Boot volumes total ${local.total_storage} GB, over the ${local.always_free.storage_max_gbs} GB tenancy allowance."
    }
    precondition {
      condition     = alltrue([for n in var.nodes : n.boot_disk_gbs >= local.always_free.min_boot_gbs])
      error_message = "Every boot volume must be at least ${local.always_free.min_boot_gbs} GB."
    }
  }
}
