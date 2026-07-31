# Homelab Infrastructure

[![CI](https://github.com/chrisleekr/homelab-infrastructure/actions/workflows/push.yml/badge.svg)](https://github.com/chrisleekr/homelab-infrastructure/actions/workflows/push.yml)
[![Container Security](https://github.com/chrisleekr/homelab-infrastructure/actions/workflows/container-security.yml/badge.svg)](https://github.com/chrisleekr/homelab-infrastructure/actions/workflows/container-security.yml)
[![Terraform](https://img.shields.io/badge/terraform-1.15.8-blue)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/kubernetes-1.36.3-blue)](https://kubernetes.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> Provisioning a Kubernetes cluster with kubeadm/k3s, Ansible and Terraform

**📖 Full documentation → <https://chrisleekr.github.io/homelab-infrastructure/>**

## Overview

A two-stage infrastructure-as-code solution for provisioning a single-node Kubernetes cluster and
deploying a complete application stack on it.

- **Stage 1 (Ansible)**: server hardening and Kubernetes bootstrap via kubeadm, k3s or minikube
- **Stage 2 (Terraform)**: 19 modules, including GitLab, ArgoCD, monitoring, logging, storage, VPN, ingress
- **Containerised tooling**: one Alpine image with kubectl, helm, terraform, ansible and bws

Supported platforms:

- **Control plane**: Ubuntu AMD64. GitLab publishes no ARM64 image.
- **Workers**: optional, AMD64 or ARM64 (e.g. a Raspberry Pi). Architecture is detected per host.
- **Kubernetes**: kubeadm (recommended), k3s (alternative), minikube (experimental).

## Documentation

| Section | Covers |
|---------|--------|
| [Get started](docs/start/index.md) | Prerequisites, secrets, both stages, verification |
| [Cluster (Stage 1)](docs/stage1/index.md) | Architecture, the `site.yml` plays, inventory, tags, handlers, all 10 roles |
| [Platform (Stage 2)](docs/stage2/index.md) | All 19 Terraform modules and the dependency graph |
| [Operations](docs/operations/index.md) | Kubernetes upgrades, adding a worker, secrets, troubleshooting |
| [Reference](docs/reference/index.md) | Version pins, `task` commands, repository layout, Terraform variables |
| [Contributing](CONTRIBUTING.md) | Development guidelines |

## Quick Start

Requires Docker and [Task](https://taskfile.dev/). Everything else runs in the container.

```bash
cp .env.example .env     # add BWS_ACCESS_TOKEN and BWS_PROJECT_ID
task repo:setup          # pre-commit hooks, ansible-galaxy, pip
task docker:build        # build the tooling image
task docker:exec         # drop into the container, secrets injected from Bitwarden
```

Then provision:

```bash
task stage1:ansible:ping        # verify SSH access
task stage1:ansible:playbook    # Stage 1: build the cluster
task stage2:terraform:apply     # Stage 2: deploy the platform
```

Stage 1 hardens hosts and may reboot them. Read
[Get started](docs/start/index.md) before running any of this.

## Toolchain

Pinned in `Dockerfile`, synced here by `scripts/sync-versions.sh`.

<!-- VERSIONS_START - Do not remove this comment, used by sync-versions workflow -->
| Tool | Version |
|------|---------|
| kubectl | 1.36.3 |
| helm | 4.2.3 |
| terraform | 1.15.8 |
| taskfile | 3.52.0 |
| trivy | 0.72.0 |
<!-- VERSIONS_END - Do not remove this comment -->

Cluster component versions live in `stage1/inventories/inventory.yml`. Both sets are documented at
[Version pins](docs/reference/versions.md).

Run `task precommit` before every commit, and work on feature branches. Infrastructure changes need
careful review.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## Security

See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
