# Operations

Runbooks for a cluster that already exists.

| Runbook | Use when |
|---|---|
| [Kubernetes upgrades](kubernetes-upgrades.md) | Moving the cluster to a new Kubernetes minor or patch |
| [Adding a worker node](adding-a-worker-node.md) | Growing the cluster |
| [Bitwarden secrets](bitwarden-secrets.md) | Adding, rotating or debugging a secret |
| [Troubleshooting](troubleshooting.md) | Something is broken |

## Symptom index

| Symptom | Start at |
|---|---|
| `task stage1:ansible:ping` fails | [Inventory and groups](../stage1/inventory.md) |
| A secret is empty inside the container | [Bitwarden secrets](bitwarden-secrets.md) |
| `LoadBalancer` service stuck `<pending>` | [`localhost_post_setup`](../stage1/roles/localhost-post-setup.md): MetalLB |
| A certificate never becomes ready | [cert-manager](../stage2/cert-manager-letsencrypt.md) |
| PVC stuck `Pending` | [Longhorn](../stage2/longhorn-storage.md) |
| A worker will not join | [`kubeadm_agent`](../stage1/roles/kubeadm-agent.md) |
| A worker will not drain during an upgrade | [Kubernetes upgrades](kubernetes-upgrades.md) |
| `kubeadm init` fails on a cgroup preflight | [Handlers](../stage1/handlers.md): the reboot did not happen |
| Locked out of a host after Stage 1 | [`host_setup`](../stage1/roles/host-setup.md): UFW and the SSH port |
| Terraform apply times out | [Stage 2: deploy the platform](../start/deploy-platform.md) |

## Safety properties worth knowing before you touch anything

!!! danger "The control plane is never drained"

    Draining a single-node control plane evicts every workload in the cluster. The upgrade
    automation deliberately does not drain it. Do not add a drain to
    `kubeadm_server/tasks/upgrade-control-plane.yml`.

!!! danger "`serial: 1` on the worker play is a correctness constraint"

    It guarantees exactly one worker is drained at a time. Raising it to go faster can evict every
    replica of a workload simultaneously.

!!! warning "Only consecutive minor upgrades are tested"

    For both Kubernetes and Cilium. Always update to the latest patch of the current minor before
    moving to the next minor.
