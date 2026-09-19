# Gateway API objects, standard channel, fetched from upstream at apply time.
#
# Istio ships none of these and will not reconcile a Gateway without them. Only the five types this
# gateway uses are installed: istiod starts an informer for every Gateway API CRD that exists, so an
# unused one buys a watch and nothing else. GRPCRoute, TLSRoute, TCPRoute and BackendTLSPolicy are
# deliberately absent, and Istio 1.31 never watches UDPRoute at all. Adding a type back is one map
# entry plus its checksum.
#
# listenersets is required, not optional: each app module contributes its own HTTPS listener through
# a ListenerSet rather than editing a central list on the Gateway.
#
# Every file is pinned by checksum, so a moved tag or a tampered response fails the apply instead of
# quietly installing different schemas. That is the reason nothing is vendored here.
#
# Refer: https://github.com/kubernetes-sigs/gateway-api/tree/main/config/crd/standard
#
# To move to a new Gateway API release: set istio_gateway_api_version, then replace the values in
# gateway_api_objects with what this prints (terraform fmt fixes the alignment):
#
#   V=v1.6.2; for f in gatewayclasses gateways httproutes listenersets referencegrants vap_safeupgrades; do \
#     printf '%-16s = "%s"\n' "$f" "$(curl -fsSL \
#       "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/$V/config/crd/standard/gateway.networking.k8s.io_$f.yaml" \
#       | shasum -a 256 | cut -d' ' -f1)"; \
#   done
locals {
  gateway_api_base = "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${var.istio_gateway_api_version}/config/crd/standard"

  # Upstream file name stem, mapped to the sha256 of that file at the pinned version.
  gateway_api_objects = {
    gatewayclasses   = "47875d2b4d7491d574ba47116226d9507e287df80463ea2cec64340d7fdae0e9"
    gateways         = "be942c2d5e2a5cd3adb506e5d19a493e412492b41577b43b49d7075674af9438"
    httproutes       = "b460061056e52495dc9450dfcccf0f060ef0f5925d04f4f4905276fdb09eb8f9"
    listenersets     = "b1487748372b0bdbdd420918e719f0c2c914d6f01154d4e42451405a73b491e5"
    referencegrants  = "430cc8bb96c4414ce178853f8a01d02c4e5ec0565fc128a4bdf21e37bade3882"
    vap_safeupgrades = "49ba8406214d445e4cea5cf21b45312cef353a9ee90eab1db41803c7458044f9"
  }

  gateway_api_crd_objects = {
    for name, sha in local.gateway_api_objects : name => sha if name != "vap_safeupgrades"
  }

  # Compare short hashes, never the body. A condition that references response_body makes Terraform
  # print the whole file in the failure diagnostic, which is 429 KB for httproutes.
  gateway_api_fetched_sha = {
    for name, doc in data.http.gateway_api : name => sha256(doc.response_body)
  }

  # Upstream ships the admission policy and its binding as two documents in one file, and
  # kubectl_manifest takes one object per resource. Index 0 is the policy, index 1 is the binding.
  gateway_api_safe_upgrades = [
    for doc in split("\n---\n", data.http.gateway_api["vap_safeupgrades"].response_body) :
    doc if trimspace(doc) != ""
  ]
}

data "http" "gateway_api" {
  for_each = local.gateway_api_objects

  url = "${local.gateway_api_base}/gateway.networking.k8s.io_${each.key}.yaml"
}

# server_side_apply is required, not a preference: the larger CRDs here exceed the 262144 byte limit
# of the kubectl.kubernetes.io/last-applied-configuration annotation that client-side apply writes.
resource "kubectl_manifest" "gateway_api_crds" {
  for_each = local.gateway_api_crd_objects

  yaml_body         = data.http.gateway_api[each.key].response_body
  server_side_apply = true

  lifecycle {
    precondition {
      condition     = local.gateway_api_fetched_sha[each.key] == each.value
      error_message = "gateway-api ${each.key} at ${var.istio_gateway_api_version} does not match its pinned checksum. Refresh the checksums as described in gateway-api-crds.tf, or treat it as a tampered download."
    }
  }
}

# Upstream's own guard against downgrading these CRDs or laying the experimental channel over the
# standard one. While it exists, any chart shipping experimental Gateway API CRDs is denied.
resource "kubectl_manifest" "gateway_api_safe_upgrades" {
  count = 2

  yaml_body         = local.gateway_api_safe_upgrades[count.index]
  server_side_apply = true

  lifecycle {
    precondition {
      condition     = local.gateway_api_fetched_sha["vap_safeupgrades"] == local.gateway_api_objects["vap_safeupgrades"]
      error_message = "gateway-api vap_safeupgrades at ${var.istio_gateway_api_version} does not match its pinned checksum. Refresh the checksums as described in gateway-api-crds.tf, or treat it as a tampered download."
    }
  }
}
