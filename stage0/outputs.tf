# Node names have to be unique across accounts: they are Kubernetes node names, and
# public_ips is a single map. Adding account2 is a concat() here and a merge() below.
output "worker_hosts_json_entries" {
  description = "Objects to append to the worker_hosts_json Bitwarden secret, one per provisioned node."
  value       = module.oci_freetier_account1.worker_hosts_json_entries
}

# Re-exported because only root outputs reach `terraform output`; left in the module alone
# it would be unreadable.
output "public_ips" {
  description = "Ephemeral public IPs keyed by node name. Present for egress via the internet gateway; nothing listens on them."
  value       = module.oci_freetier_account1.public_ips
}
