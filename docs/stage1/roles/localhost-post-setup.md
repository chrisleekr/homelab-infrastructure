# localhost_post_setup

Runs on your machine, not on the cluster. Finishes the install by wiring up local kubectl access and installing the two add-ons Stage 2 assumes are present.

**Invoked by** play 6 (`hosts: localhost`, `connection: local`), tag `post_setup`.

## Task files

| File | Tag | Does |
|---|---|---|
| `rename-kubeconfig.yml` | `kubeconfig` | Moves the kubeconfig fetched by `kubeadm_server/tasks/download-kubeconfig.yml` into `container/root/.kube/config` |
| `install-metallb.yml` | `network` | Installs MetalLB so `LoadBalancer` services get a real LAN IP |
| `install-metrics-server.yml` | `monitoring` | Installs metrics-server so `kubectl top` and HPAs work |

The last two sit inside a `when: kubernetes_cluster_type == 'kubeadm'` block. On k3s and minikube only the kubeconfig rename runs.

## Why MetalLB matters

A bare-metal cluster has no cloud load balancer, so a `Service` of type `LoadBalancer` stays `Pending` forever. MetalLB assigns it an address from a LAN pool.

Stage 2's [NGINX ingress controller](../../stage2/nginx.md) is exposed as a `LoadBalancer`, so without MetalLB nothing in the platform is reachable. This is the single most common cause of "the apply succeeded but I cannot reach anything".

## Variables

None.

## Re-run behaviour

Idempotent. Re-running is the supported way to refresh a stale local kubeconfig:

```bash
cd stage1
ansible-playbook -i inventories/inventory.yml site.yml --tags post_setup
```

Note there is no `--ask-become-pass`: this play does not use `become`.

## Gotchas

!!! note "The kubeconfig lands inside the container mount"

    `container/root/.kube/config` is bind-mounted into the tooling container, which is why `task docker:exec` gives you a working `kubectl` with no further setup. It is gitignored.

!!! warning "Skipped by the worker-only task"

    `task stage1:ansible:playbook:worker` passes `--skip-tags post_setup`, so adding a worker does not touch your kubeconfig, MetalLB or metrics-server. That is intended, but it means a worker-only run never refreshes local credentials.
