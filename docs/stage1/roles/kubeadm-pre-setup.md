# kubeadm_pre_setup

Prepares a host for kubeadm. The smallest role in Stage 1: one task file, no defaults.

**Invoked by** play 3 (`hosts: server`) and play 4 (`hosts: agent`), both when `kubernetes_cluster_type == 'kubeadm'`. Tag `bootstrap`.

It runs on **both** the control plane and every worker, always before [`kubeadm_server`](kubeadm-server.md) or [`kubeadm_agent`](kubeadm-agent.md).

## What `bootstrap-node.yml` does

| Step | Why |
|---|---|
| Refresh the APT cache and upgrade packages | A stale cache breaks the package installs that follow |
| Install prerequisite packages | kubeadm's own preflight requires several of them |
| Load kernel modules (`overlay`, `br_netfilter`) | containerd needs `overlay`; pod networking needs `br_netfilter` |
| Apply sysctl settings | `net.bridge.bridge-nf-call-iptables`, `net.ipv4.ip_forward` |
| Stop AppArmor | It interferes with container runtime profiles on Ubuntu |
| Disable unattended-upgrades | An unattended kubelet or containerd upgrade mid-cluster is a silent version skew |

## Variables

None. Everything comes from the inventory and gathered facts.

## Handlers notified

None. Sysctl settings use `ansible.posix.sysctl` with `reload: true`, which applies them inline rather than through a handler.

## Re-run behaviour

Idempotent, though the APT upgrade step will report changes whenever new packages are available upstream.

## Gotchas

!!! warning "Disabling unattended-upgrades is deliberate"

    Leaving it on means Ubuntu can upgrade `kubelet`, `kubeadm` or `containerd` out from under the cluster, producing a version skew nothing in this repo pinned or approved. If you re-enable it, hold those packages explicitly.

!!! note "This role runs twice on a mixed cluster"

    Once for `hosts: server` in play 3, once for `hosts: agent` in play 4. That is intentional: the two plays run at different times and a worker added later still needs bootstrapping.
