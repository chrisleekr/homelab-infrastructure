# minikube_pre_setup

Installs Docker, which minikube uses as its driver. Selected when
`kubernetes_cluster_type == 'minikube'`.

**Invoked by** play 3 (`hosts: server`), tag `minikube`.

!!! warning "The minikube path is experimental"

    It provisions, but it is not known to work end to end with the Stage 2 platform. Use
    [kubeadm](kubeadm-server.md) for anything you intend to keep.

## What it does

`tasks/setup-docker.yml`, tagged `container_runtime`:

- Installs Docker from the official repository
- Configures the daemon data root from `host_setup_docker_default_data_path`
- Enables and starts the service

## Variables

None of its own. Reads `host_setup_docker_default_data_path` from
[`host_setup`](host-setup.md).

## Re-run behaviour

Idempotent.

## Gotchas

!!! note "Docker here, containerd everywhere else"

    The kubeadm path deliberately does **not** install Docker. It uses containerd directly via the
    CRI. Only minikube needs a Docker daemon. If you switch cluster types on a host you will end up
    with both.
