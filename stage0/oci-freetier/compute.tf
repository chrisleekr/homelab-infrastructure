data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid

  # Without this, an empty list surfaces as "Invalid index" mid-apply, after the
  # network is already created.
  lifecycle {
    postcondition {
      condition     = length(self.availability_domains) > 0
      error_message = "No availability domains returned for this tenancy. The Terraform user most likely lacks tenancy-level inspect rights."
    }
  }
}

data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"

  lifecycle {
    postcondition {
      condition     = length(self.images) > 0
      error_message = "No Canonical Ubuntu 24.04 image for VM.Standard.A1.Flex in this region. Check operating_system_version against the console image list."
    }
  }
}

resource "oci_core_instance" "worker" {
  for_each = var.nodes

  depends_on = [terraform_data.freetier_guard]

  # Index 0 rather than a spread: several APAC regions have exactly one AD, and Always
  # Free capacity is per AD, so retrying is what finds capacity, not fanning out.
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = each.key
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = each.value.ocpus
    memory_in_gbs = each.value.memory_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = each.value.boot_disk_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    nsg_ids          = [oci_core_network_security_group.worker.id]
    assign_public_ip = true
    hostname_label   = each.key
  }

  # Blocks the unauthenticated IMDSv1 endpoint, so a blind SSRF that cannot set headers
  # is shut out of the cloud-init payload. It is not a session-token scheme: IMDSv2 takes
  # a static, publicly documented `Authorization: Bearer Oracle` header, so anything on
  # the node that can set one still reads user_data, auth key included.
  # https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/gettingmetadata.htm
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      tailscale_auth_key = var.tailscale_auth_key
      tailscale_hostname = each.key
      ssh_ingress_cidrs  = var.ssh_ingress_cidrs
    }))
  }

  # source_id is Updatable for Linux images, so a newer Canonical publish would be an
  # in-place boot volume replacement on an already-joined node, terminating the old
  # volume. Re-image deliberately with `apply -replace`, never as apply drift.
  # https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_instance
  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}
