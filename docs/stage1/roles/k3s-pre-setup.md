# k3s_pre_setup

Prerequisites for the k3s path. Selected when `kubernetes_cluster_type == 'k3s'`.

**Invoked by** play 3 (`hosts: server`), tag `k3s`.

## What it does

One `tasks/main.yml`, considerably more branching than the kubeadm equivalent because it carries upstream's multi-distribution support.

| Step | Notes |
|---|---|
| Enforce a minimum Ansible version | Fails fast rather than erroring obscurely later |
| Install dependent packages | Ubuntu only |
| Enable IPv4 forwarding | Always |
| Enable IPv6 forwarding | Only when the host has IPv6 addresses |
| Open firewall ports | Handles both UFW and firewalld, detected via `service_facts` |
| Load `br_netfilter` | RedHat and Arch only; Ubuntu gets it elsewhere |
| Install the AppArmor parser | SUSE and Debian branches |
| Warn on iptables 1.8.0–1.8.4 | A known-broken range for Kubernetes |
| Add `/usr/local/bin` to sudo `secure_path` | RedHat only, where it is missing by default |
| Set up an alternative k3s data directory | When configured |
| Write extra manifests and private-registry config | When configured |

## Variables

| Variable | Purpose |
|---|---|
| `api_port` | Kubernetes API server port to open in the firewall |
| `server_group` | Inventory group holding k3s servers |
| `agent_group` | Inventory group holding k3s agents |

## Firewall handling

The role opens the API port unconditionally, and opens etcd ports only when `groups[server_group] | length > 1`, that is, only for an HA control plane. A homelab single-node install never needs them.

## Re-run behaviour

Idempotent.

## Gotchas

!!! warning "This role is inherited from upstream and is broader than this repo needs"

    It handles RedHat, SUSE, Arch and Debian. In this repository only the Ubuntu paths are exercised, so the others are effectively untested here.

!!! note "k3s does not use Cilium"

    k3s ships flannel and its own service proxy. The `cilium_version` pins are inert on this path, as is everything under [`kubeadm_node`](kubeadm-node.md).

!!! danger "No worker or upgrade support"

    Play 4 is kubeadm-only, and so is the upgrade machinery in play 5. Choosing k3s means a single-node cluster with manual upgrades.
