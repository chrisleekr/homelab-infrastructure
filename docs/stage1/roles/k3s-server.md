# k3s_server

Installs and runs k3s as a systemd service. Selected when `kubernetes_cluster_type == 'k3s'`.

**Invoked by** play 3 (`hosts: server`), tag `k3s`, after [`k3s_pre_setup`](k3s-pre-setup.md).

## What it does

| Step | Notes |
|---|---|
| Probe the installed k3s version | Skips reinstall when already on target |
| Download the k3s binary | Architecture-aware |
| Install the systemd unit | One of three templates, see below |
| Start and enable the service | |
| Merge the kubeconfig back to the control node | So `kubectl` works locally |
| Set up kubectl | Context named by `cluster_context` |

## Systemd unit templates

| Template | Used for |
|---|---|
| `k3s-single.service.j2` | Single server, the homelab case |
| `k3s-cluster-init.service.j2` | First server of an HA cluster, `--cluster-init` |
| `k3s-ha.service.j2` | Subsequent HA servers, joining the first |

## Variables

| Variable | Purpose |
|---|---|
| `k3s_server_location` | Data directory |
| `systemd_dir` | Where the unit file is written |
| `api_port` | API server port |
| `kubeconfig` | Path to write the merged kubeconfig |
| `user_kubectl` | Whether to configure kubectl for the invoking user |
| `cluster_context` | kubeconfig context name |
| `server_group`, `agent_group` | Inventory groups |

## Version pin

`k3s_version` in `stage1/inventories/inventory.yml`. Note its format differs from every other pin. It is a full tag like `v1.34.3+k3s1`, not a bare semver. See [Version pins](../../reference/versions.md).

## Re-run behaviour

Idempotent. The version probe short-circuits the download and install when already current.

## Gotchas

!!! danger "Changing `kubernetes_cluster_type` on a live host does not migrate anything"

    Switching from k3s to kubeadm, or back, runs the other path's install against a host that already has a cluster on it. Nothing tears the old one down. Rebuild the host instead.

!!! note "k3s is not covered by the upgrade automation"

    Plays 4 and 5, the preflight gates, drain ordering and postflight verification are all kubeadm only. Upgrading k3s means bumping `k3s_version` and re-running this role, with no health gates.
