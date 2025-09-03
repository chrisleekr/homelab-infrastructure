# My internet provider does not support hairpin NAT, so I need to use the custom coredns config to avoid it.
# @coredns-custom.tf is not working anymore as `import` statement is deprecated.

# This is default coredns configmap.
# $ kubectl get configmap -nkube-system coredns -oyaml
# apiVersion: v1
# data:
#   Corefile: |
#     .:53 {
#         errors
#         health {
#            lameduck 5s
#         }
#         ready
#         kubernetes cluster.local in-addr.arpa ip6.arpa {
#            pods insecure
#            fallthrough in-addr.arpa ip6.arpa
#            ttl 30
#         }
#         prometheus :9153
#         forward . /etc/resolv.conf {
#            max_concurrent 1000
#         }
#         cache 30 {
#            disable success cluster.local
#            disable denial cluster.local
#         }
#         loop
#         reload
#         loadbalance
#     }
# kind: ConfigMap
#
# This is updated coredns configmap by this module.
# apiVersion: v1
# data:
#   Corefile: |
#     .:53 {
#         errors
#         health {
#            lameduck 5s
#         }
#         ready
#         kubernetes cluster.local in-addr.arpa ip6.arpa {
#            pods insecure
#            fallthrough in-addr.arpa ip6.arpa
#            ttl 30
#         }
#         prometheus :9153
#         forward . /etc/resolv.conf {
#            max_concurrent 1000
#                             except minio.chrislee.local gitlab.chrislee.local registry.chrislee.local
#         }
#         cache 30 {
#            disable success cluster.local
#            disable denial cluster.local
#         }
#         loop
#         reload
#         loadbalance
#     }
#     # START: custom DNS
#     minio.chrislee.local:53 {
#         errors
#         hosts {
#             192.168.1.202 minio.chrislee.local
#             fallthrough
#         }
#         cache 30
#     }
#     gitlab.chrislee.local:53 {
#         errors
#         hosts {
#             192.168.1.202 gitlab.chrislee.local
#             fallthrough
#         }
#         cache 30
#     }
#     registry.chrislee.local:53 {
#         errors
#         hosts {
#             192.168.1.202 registry.chrislee.local
#             fallthrough
#         }
#         cache 30
#     }
#     # END: custom DNS


# Get the existing CoreDNS ConfigMap
data "kubernetes_config_map" "coredns_existing" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
}

locals {
  existing_corefile = data.kubernetes_config_map.coredns_existing.data["Corefile"]
  domain_list       = split(" ", trim(var.kubernetes_override_domains, "\""))

  # Use markers to identify modifications
  start_marker = "# START: custom DNS"
  end_marker   = "# END: custom DNS"

  # Step 1: Remove any existing custom configuration between markers
  # This will replace markers with empty string
  without_custom_config = (can(regex("${local.start_marker}", local.existing_corefile)) ?
    replace(
      local.existing_corefile,
      "/(?s)${local.start_marker}.*?${local.end_marker}/",
      ""
  ) : local.existing_corefile)

  # Step 2: Update forward directive with preserving existing
  # Extract the current forward directive and its block
  forward_pattern = "forward \\. /etc/resolv\\.conf(?:\\s*\\{[^}]*\\})?"
  # `try` evaluates all of its argument expressions in turn and returns the result of the first one that does not produce any errors.
  # `regex` applies a regular expression to a string and returns the matching substrings.
  existing_forward = try(regex(local.forward_pattern, local.without_custom_config), "forward . /etc/resolv.conf")

  # Build except clause for all domains
  except_clause = join(" ", local.domain_list)

  # Always rebuild the forward directive to ensure it matches exactly the current domain list
  new_forward = (
    can(regex("forward \\. /etc/resolv\\.conf \\{", local.existing_forward)) ?
    # Extract existing forward block content, remove any except clauses, add new except clause
    replace(
      replace(local.existing_forward, "/except [^}\\n]*\\n?/", ""),
      "/\\}/",
      "        except ${local.except_clause}\n    }"
    ) :
    # If it does not have a forward block, convert to block with except
    "forward . /etc/resolv.conf {\n        except ${local.except_clause}\n    }"
  )

  # Step 3: Replace the forward directive
  base_corefile = replace(local.without_custom_config, local.existing_forward, local.new_forward)

  # Step 4: Create server blocks for each domain
  custom_configs = [for domain in local.domain_list : <<EOF

${domain}:53 {
    errors
    hosts {
        ${var.kubernetes_override_ip} ${domain}
        fallthrough
    }
    cache 30
}
EOF
  ]

  # Step 5: Combine all custom configs with markers
  all_custom_config = <<EOF

${local.start_marker}${join("", local.custom_configs)}
${local.end_marker}
EOF

  # Final Corefile
  modified_corefile = "${local.base_corefile}${local.all_custom_config}"
}

# Manage the existing CoreDNS ConfigMap
# Note: you must import the existing resource first before applying the modified version.
#       It may not work if the cluster is new cluster. Comment out first and then rerun the command.
# $ cd stage2
# $ terraform import 'module.kubernetes.kubernetes_config_map.coredns[0]' kube-system/coredns
# Acquiring state lock. This may take a few moments...

# Import successful!

# The resources that were imported are shown above. These resources are now in
# your Terraform state and will henceforth be managed by Terraform.
# $ terraform state list | grep coredns
# module.kubernetes.kubernetes_config_map.coredns[0]
resource "kubernetes_config_map" "coredns" {
  count = var.kubernetes_cluster_type == "kubeadm" ? 1 : 0

  metadata {
    name      = "coredns"
    namespace = "kube-system"
    labels    = data.kubernetes_config_map.coredns_existing.metadata[0].labels
  }

  data = {
    Corefile = local.modified_corefile
  }

  lifecycle {
    # Allow Terraform to take over management of existing resource
    create_before_destroy = false
  }
}
