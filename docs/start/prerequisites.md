# Prerequisites

## On your machine

| Need | Why |
|---|---|
| Docker | The whole toolchain runs in a container |
| [Task](https://taskfile.dev/) | The command interface; every operation is a `task` |
| An SSH keypair, e.g. `~/.ssh/id_rsa.pub` | Ansible authenticates with it |
| Git | |

Nothing else. kubectl, helm, terraform, ansible and `bws` all live in the container image. See
[Version pins](../reference/versions.md) for exactly which versions.

## Accounts

| Service | Used for |
|---|---|
| [Terraform Cloud](https://app.terraform.io/) | Remote state backend. Create a workspace and an API token. |
| [Bitwarden Secrets Manager](https://bitwarden.com/products/secrets-manager/) | Every secret and config value. Create a project and a machine account. |
| [Auth0](https://auth0.com/) | OAuth2 login in front of Grafana, ArgoCD and the rest |
| A domain | Services are exposed as `service.<domain>`. The `letsencrypt-prod` issuer solves ACME HTTP-01, so a certificate needs a publicly resolvable name reachable on port 80. A `.local` name is LAN-only and Let's Encrypt will not issue for it. |

## The control-plane host

!!! warning "AMD64 recommended for the control plane"

    `registry.gitlab.com/gitlab-org/build/cng/kubectl` publishes no ARM64 image, so on an ARM64
    control plane the Stage 2 GitLab module is skipped. Everything else deploys normally. Workers
    may be either architecture.

Install Ubuntu Server, then make two changes.

### 1. Move sshd off port 22

Stage 1's UFW configuration rate-limits port 22 and opens the host's actual `ansible_port`. Running
sshd on 22 means you are rate-limiting your own automation.

```bash
ssh <user>@<control-plane-ip>

# Check how sshd is activated on this image first: socket or service.
systemctl status ssh.socket ssh.service --no-pager

# If socket-activated, override it. The empty ListenStream= is required:
# ListenStream is a list, so without the reset the vendor unit's port 22
# stays active and sshd listens on both.
sudo install -d /etc/systemd/system/ssh.socket.d
printf '[Socket]\nListenStream=\nListenStream=2222\n' \
  | sudo tee /etc/systemd/system/ssh.socket.d/listen.conf
sudo systemctl daemon-reload && sudo systemctl restart ssh.socket
```

!!! danger "Confirm the new port from a second terminal before closing this one"

    ```bash
    ssh -p 2222 <user>@<control-plane-ip> true && echo "2222 OK"
    ```

    Getting this wrong locks you out of the host.

The worker runbook covers the same change in more detail, including the service-activated case:
[Adding a worker node](../operations/adding-a-worker-node.md).

### 2. Install your public key

```bash
ssh -p 2222 <user>@<control-plane-ip>
vim ~/.ssh/authorized_keys
# paste the contents of ~/.ssh/id_rsa.pub
```

Confirm key-based login works before continuing. Ansible does not prompt for an SSH password.

## Workers (optional)

Skip this for a single-node cluster.

Workers may be AMD64 or ARM64. A Raspberry Pi works. Each needs the same treatment as above: a
reachable IP, a non-default SSH port, and your public key installed.

For Raspberry Pi there are cloud-init examples in the repository that do all of this at first boot:

- [`user-data.example`](https://github.com/chrisleekr/homelab-infrastructure/blob/main/stage1/cloud-init/raspberry-pi/user-data.example)
- [`network-config.example`](https://github.com/chrisleekr/homelab-infrastructure/blob/main/stage1/cloud-init/raspberry-pi/network-config.example)

Full walkthrough: [Adding a worker node](../operations/adding-a-worker-node.md).

## Next

[Stage 0: environment and secrets](environment.md)
