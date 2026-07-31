# Cluster (Stage 1)

Stage 1 is Ansible. It takes a freshly installed Ubuntu host, hardens it, and turns it into a
Kubernetes control plane, plus any worker nodes you have declared.

Everything runs from one playbook, `stage1/site.yml`, driven by
`stage1/inventories/inventory.yml`.

```bash
task stage1:ansible:playbook
```

## What it produces

| Layer | Component |
|---|---|
| Host | Ubuntu with swap disabled, memory cgroups enabled, UFW, fail2ban, snapd removed |
| Container runtime | containerd + runc, with crictl and nerdctl for debugging |
| Kubernetes | kubeadm-provisioned control plane, kubelet as a systemd unit |
| Networking | Cilium CNI, MetalLB for LoadBalancer services |
| Metrics | metrics-server, so `kubectl top` works |

## Cluster types

`kubernetes_cluster_type` (a Bitwarden secret, see [Bitwarden secrets](../operations/bitwarden-secrets.md))
selects one of three mutually exclusive paths in play 3.

=== "kubeadm (recommended)"

    Full upstream Kubernetes. This is the only path with worker-node support, rolling upgrades,
    preflight checks and Cilium. Everything else in these docs assumes kubeadm unless stated.

    Roles: [`kubeadm_pre_setup`](roles/kubeadm-pre-setup.md) → [`kubeadm_server`](roles/kubeadm-server.md),
    with [`kubeadm_node`](roles/kubeadm-node.md) pulled in as a dependency.

=== "k3s"

    Lightweight single-binary Kubernetes for resource-constrained hosts. No worker plays, no upgrade
    automation, built-in CNI instead of Cilium.

    Roles: [`k3s_pre_setup`](roles/k3s-pre-setup.md) → [`k3s_server`](roles/k3s-server.md).

=== "minikube (experimental)"

    Runs Kubernetes inside Docker on the host. Provisions, but is not known to work end to end with
    the Stage 2 platform.

    Roles: [`minikube_pre_setup`](roles/minikube-pre-setup.md) → [`minikube_server`](roles/minikube-server.md).

## Where to go next

| I want to | Read |
|---|---|
| Understand what runs on a node and why | [Architecture](architecture.md) |
| Understand the playbook's six plays and their safety knobs | [The site.yml playbook](playbook.md) |
| Add a worker, or understand `worker_hosts_json` | [Inventory and groups](inventory.md) |
| Re-run only part of the playbook | [Tags and partial runs](tags.md) |
| Know what triggers a reboot | [Handlers](handlers.md) |
| Read what a specific role does | [Roles](roles/index.md) |
| Upgrade Kubernetes | [Kubernetes upgrades](../operations/kubernetes-upgrades.md) |
