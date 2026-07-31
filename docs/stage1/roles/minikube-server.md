# minikube_server

Installs minikube and runs it as a pair of systemd services. Selected when `kubernetes_cluster_type == 'minikube'`.

**Invoked by** play 3 (`hosts: server`), tag `minikube`, after [`minikube_pre_setup`](minikube-pre-setup.md).

!!! warning "Experimental"

    Provisions, but is not known to work end to end with the Stage 2 platform. Use [kubeadm](kubeadm-server.md) for anything you intend to keep.

## Task files

| File | Does |
|---|---|
| `install-minikube.yml` | Downloads the minikube redistributable for `host_machine_architecture` |
| `setup-minikube-services.yml` | Installs the `minikube` and `minitunnel` systemd units |
| `generate-kubeconfig.yml` | Writes a kubeconfig pointing at the started cluster |

## The two services

| Unit | Template | Purpose |
|---|---|---|
| `minikube` | `minikube.service.j2` | Starts the cluster at boot |
| `minitunnel` | `minitunnel.service.j2` | Runs `minikube tunnel`, which is what gives `LoadBalancer` services an address |

`minitunnel` is minikube's substitute for MetalLB. On the kubeadm path, MetalLB does this job instead. See [`localhost_post_setup`](localhost-post-setup.md).

## Handlers notified

`enable minikube`, `start minikube`, `enable minitunnel`, `start minitunnel`, all from `stage1/handlers/minikube.yml`, which only play 3 imports.

## Variables

| Variable | Purpose |
|---|---|
| `kubeconfig` | Where the generated kubeconfig is written |

Version pin: `minikube_version` in `stage1/inventories/inventory.yml`.

## Re-run behaviour

Idempotent.

## Gotchas

!!! note "Architecture comes from `host_machine_architecture`, not `node_architecture`"

    The minikube download uses the cluster-wide architecture variable rather than the per-host fact. That is fine because minikube only ever runs on the single `server` host, but it is inconsistent with the kubeadm path, where every binary keys off `node_architecture`.

!!! danger "No workers, no upgrades"

    Play 4 is kubeadm-only and so is every upgrade gate. minikube gives you a single node with manual upgrades.
