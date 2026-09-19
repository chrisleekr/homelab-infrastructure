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
data "kubernetes_config_map_v1" "coredns_existing" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
}

locals {
  existing_corefile = data.kubernetes_config_map_v1.coredns_existing.data["Corefile"]
  domain_list       = compact(split(" ", trim(var.kubernetes_override_domains, "\"")))

  # Hosts already serving from the Istio gateway. Kept separate from domain_list: a name belongs to
  # exactly one of the two, and a cutover moves it across.
  gateway_domain_list = compact(split(" ", trim(var.kubernetes_gateway_domains, "\"")))

  # Use markers to identify modifications
  start_marker = "# START: custom DNS"
  end_marker   = "# END: custom DNS"

  # Step 1: Remove any existing custom configuration between markers
  # This will replace markers with empty string
  without_custom_config = (can(regex(local.start_marker, local.existing_corefile)) ?
    replace(
      local.existing_corefile,
      "/\\n*(?s)${local.start_marker}.*?${local.end_marker}/",
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

  # forward's except takes one or more zones, so an empty domain list has to drop the clause, not
  # emit a bare "except". CoreDNS rejects the whole Corefile on a zero-arg except, and a rejected
  # Corefile only fails the reload: the pods keep serving the last good config out of memory and
  # crashloop later, whenever something restarts them. Worse, the bare-except render is a fixed
  # point, so a later apply sees no diff and never repairs it.
  #
  # Strip any existing except line first, so the empty and non-empty cases both start from a forward
  # block without one. That also clears the runaway indentation the add-if-missing branch used to
  # accumulate, one insert per apply that failed to match its own except regex.
  forward_without_except = replace(local.existing_forward, "/\\n[ \\t]*except[^}\\n]*/", "")

  # Always rebuild the forward directive to ensure it matches exactly the current domain list
  new_forward = (
    length(local.domain_list) == 0 ? local.forward_without_except :
    can(regex("forward \\. /etc/resolv\\.conf \\{", local.forward_without_except)) ?
    # Has a forward block, already stripped of its except line, so insert before the closing brace
    replace(local.forward_without_except, "/\\s*\\}/", "\n                             except ${local.except_clause}\n    }") :
    # No forward block at all
    "forward . /etc/resolv.conf {\n                             except ${local.except_clause}\n    }"
  )


  # Step 3: Replace the forward directive, then inject the gateway rewrites.
  #
  # A host served by the gateway must resolve in-cluster to the gateway Service, not to the LAN
  # address. rewrite runs before kubernetes and forward in the CoreDNS plugin chain, so the rewritten
  # name is answered by the cluster plugin and the query never leaves the cluster. CoreDNS restores the original name
  # in the answer for exact "rewrite name" rules, so the client still sees the name it asked for and
  # TLS SNI still carries the public hostname, which is what selects the gateway listener.
  #
  # Unlike the per-domain blocks below, these lines sit in the MAIN server block, which the
  # START/END markers do not cover. They are stripped and rebuilt on every apply; without the strip
  # each apply would append another copy.
  gateway_rewrite_lines = join("", [
    for domain in local.gateway_domain_list :
    "    rewrite name ${domain} ${var.kubernetes_gateway_service_fqdn}\n"
  ])

  corefile_without_rewrites = replace(
    local.without_custom_config,
    "/(?m)^[ \\t]*rewrite name \\S+ ${replace(var.kubernetes_gateway_service_fqdn, ".", "\\.")}[ \\t]*\\n/",
    ""
  )

  base_corefile = replace(
    replace(local.corefile_without_rewrites, local.existing_forward, local.new_forward),
    "/(\\.:53 \\{\\n)/",
    "$1${local.gateway_rewrite_lines}"
  )

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
${local.start_marker}
${join("", local.custom_configs)}${local.end_marker}
EOF

  # Final Corefile
  modified_corefile = "${local.base_corefile}${local.all_custom_config}"
}

# kubeadm creates this ConfigMap, so import it before the first Stage 2 apply:
# terraform -chdir=stage2 import 'module.kubernetes.kubernetes_config_map_v1.coredns[0]' kube-system/coredns
resource "kubernetes_config_map_v1" "coredns" {
  count = var.kubernetes_cluster_type == "kubeadm" ? 1 : 0

  metadata {
    name      = "coredns"
    namespace = "kube-system"
    labels    = data.kubernetes_config_map_v1.coredns_existing.metadata[0].labels
  }

  data = {
    Corefile = local.modified_corefile
  }

  lifecycle {
    # Allow Terraform to take over management of existing resource
    create_before_destroy = false
  }
}
