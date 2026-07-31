# Tags and partial runs

Stage 1 defines 22 tags. They let you re-run one slice of the playbook instead of the whole thing,
which matters because a full run reboots hosts and drains workers.

```bash
cd stage1
ansible-playbook --ask-become-pass -i inventories/inventory.yml site.yml --tags <tag>
```

## Play and cluster-type selectors

| Tag | Selects |
|---|---|
| `always` | Play 1, worker registration. Runs regardless of `--tags`, so the `agent` group is always populated. |
| `host_setup` | Play 2, the whole `host_setup` role |
| `kubeadm` | The kubeadm block in play 3, plus postflight verification in play 5 |
| `k3s` | The k3s block in play 3 |
| `minikube` | The minikube block in play 3 |
| `kubeadm_agent` | Play 4, worker join and upgrade |
| `post_setup` | Play 6, kubeconfig, MetalLB, metrics-server |

## `host_setup` sub-tags

| Tag | Task files |
|---|---|
| `packages` | `install-packages.yml`, `remove-snapd.yml` |
| `network` | `update-etc-hosts.yml`, `update-sysctl.yml`, and `install-metallb.yml` in play 6 |
| `storage` | `update-multipath.yml` |
| `security` | `install-fail2ban.yml`, `setup-ufw.yml` |
| `system` | `disable-swap.yml`, `enable-memory-cgroup.yml` |

## Kubernetes lifecycle tags

| Tag | Selects |
|---|---|
| `bootstrap` | `kubeadm_pre_setup`, apt refresh, kernel modules, sysctl |
| `container_runtime` | containerd and runc installation |
| `container_tools` | crictl, nerdctl |
| `cni` | CNI plugin binaries |
| `k8s_install` | First-time install paths, skipped once the node is bootstrapped |
| `k8s_upgrade` | Preflight checks, control-plane upgrade, worker roll, postflight verify |
| `k8s_config` | Cluster configuration after install |
| `kubeconfig` | Fetching and renaming the kubeconfig |
| `monitoring` | metrics-server |
| `system_upgrade` | OS package upgrades |

## Common recipes

=== "Re-harden hosts only"

    ```bash
    ansible-playbook --ask-become-pass -i inventories/inventory.yml site.yml \
      --tags host_setup
    ```

    Safe to re-run. Note it may still reboot if a memory-cgroup change is pending.

=== "Firewall and fail2ban only"

    ```bash
    ansible-playbook --ask-become-pass -i inventories/inventory.yml site.yml \
      --tags security
    ```

=== "Kubernetes upgrade"

    ```bash
    ansible-playbook --ask-become-pass -i inventories/inventory.yml site.yml \
      --tags k8s_upgrade
    ```

    Runs preflights, upgrades the control plane, rolls the workers one at a time, then verifies
    convergence. See [Kubernetes upgrades](../operations/kubernetes-upgrades.md) first. This
    drains workers.

=== "Workers only, leave the control plane alone"

    ```bash
    task stage1:ansible:playbook:worker
    ```

    Equivalent to `--limit 'localhost:agent' --skip-tags post_setup`.

=== "Refresh the local kubeconfig"

    ```bash
    ansible-playbook -i inventories/inventory.yml site.yml --tags post_setup
    ```

!!! warning "Tags on dynamic includes need `apply:`"

    A tag on `include_role` or `include_tasks` selects only the include task, never the tasks it
    pulls in. Stage 1 therefore writes:

    ```yaml
    ansible.builtin.include_tasks:
      file: preflight-version-skew.yml
      apply:
        tags: [k8s_upgrade]
    tags: [k8s_upgrade]
    ```

    Both lines are required. Drop the `apply:` block and `--tags k8s_upgrade` silently becomes a
    no-op: it matches the include, runs nothing inside it, and reports success.

## Listing what a tag would do

```bash
ansible-playbook -i inventories/inventory.yml site.yml --list-tasks --tags k8s_upgrade
```

Static analysis only, no connection. Note that tasks behind a dynamic include do not appear until
the include runs, so the list understates the real work.
