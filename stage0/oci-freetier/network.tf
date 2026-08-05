# Account-level, created once per workspace regardless of node count.

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "homelab-vcn"
  dns_label      = "homelab"
}

# Adopted rather than created. A VCN's default security list ships an SSH ingress rule,
# and any subnet added later without security_list_ids inherits it, so emptying it is what
# stops this class of hole from reappearing outside this file.
# https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Tasks/terraform-manage-default-vcn-resources.htm
resource "oci_core_default_security_list" "vcn_default" {
  manage_default_resource_id = oci_core_vcn.main.default_security_list_id

  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "homelab-igw"
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "homelab-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

# Pinning an owned, ingress-free list is what makes the NSG authoritative. A subnet with
# no security_list_ids inherits the VCN default list, which ships a stateful ingress rule
# on port 22, and security lists are unioned with NSGs rather than intersected, so that
# one rule would defeat the whole zero-ingress posture on a public IP.
# https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/securitylists.htm
resource "oci_core_security_list" "no_ingress" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "homelab-no-ingress"

  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }
}

resource "oci_core_subnet" "public" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = "10.0.0.0/24"
  display_name      = "homelab-public"
  dns_label         = "public"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.no_ingress.id]
}

resource "oci_core_network_security_group" "worker" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "homelab-worker-nsg"
}

# Egress only. Tailscale does outbound NAT traversal with DERP fallback, so the nodes
# need no inbound rule at all. Egress stays open because a Kubernetes node needs
# registries, apt and DERP, and a restricted list would break silently.
resource "oci_core_network_security_group_security_rule" "egress_all" {
  network_security_group_id = oci_core_network_security_group.worker.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# Created only when ssh_ingress_cidrs is non-empty. The normal state is no rule.
resource "oci_core_network_security_group_security_rule" "ssh_ingress" {
  for_each = toset(var.ssh_ingress_cidrs)

  network_security_group_id = oci_core_network_security_group.worker.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = each.value
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}
