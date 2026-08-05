# node_ip is deliberately absent: Terraform does not know the tailnet address. Read it
# from `tailscale status` after apply and add it to the JSON, as the runbook describes.
output "worker_hosts_json_entries" {
  description = "Objects to append to the worker_hosts_json Bitwarden secret, one per node."
  value = [
    for name, _ in var.nodes : {
      name        = name
      host        = name # Tailscale MagicDNS name
      user        = "ubuntu"
      snapd_purge = false # keeps the Oracle Cloud Agent snap
      taints      = [{ key = "node.homelab/class", value = "cloud", effect = "NoSchedule" }]
      labels      = { "node.homelab/class" = "cloud" }
    }
  ]
}

output "public_ips" {
  description = "Ephemeral public IPs, keyed by node name. Present for egress via the internet gateway; nothing listens on them."
  value       = { for k, v in oci_core_instance.worker : k => v.public_ip }
}
