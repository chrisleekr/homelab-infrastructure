# Task commands

Every operation in this repository goes through [Task](https://taskfile.dev/). Naming follows
`area:verb:qualifier`.

```bash
task --list          # everything with a desc
task --list-all      # including the undescribed ones
```

!!! info "Run tasks inside the container"

    The image ships `task` itself and mounts the repo at `/srv`, so every target below is available
    from `task docker:exec`. Run them there: that is where the pinned toolchain lives and where
    `.bashrc` has injected the Bitwarden secrets. Two exceptions run on the host: `docker:*`, which
    needs a Docker daemon the image does not have, and `repo:setup:mac`, which is Homebrew.

## Repository setup

| Command | Does |
|---|---|
| `task repo:setup:mac` | Homebrew prerequisites, macOS only |
| `task repo:setup` | `pre-commit autoupdate`, Ansible Galaxy collections, Python requirements |
| `task precommit` | `pre-commit run --all-files`. Run before every commit. |

## Container

Host-only: the image has no Docker CLI.

| Command | Does |
|---|---|
| `task docker:build` | Build the Alpine tooling image. Accepts CLI args, e.g. `-- --no-cache`. |
| `task docker:run` | Start the container with the repo and kubeconfig mounted |
| `task docker:exec` | Start if needed, then drop into bash |
| `task docker:trivy` | Rebuild with `--no-cache` and scan for CVEs, matching the CI workflow |

## Documentation

| Command | Does |
|---|---|
| `task docs:install` | Create `.venv-docs/` from `docs/requirements.txt`. Re-runs only when the pin file changes. |
| `task docs:serve` | Live-reload server on <http://127.0.0.1:8000> |
| `task docs:build` | `mkdocs build --strict`. Any warning is an error, so this is the link checker. |
| `task docs:check` | Every drift gate, exactly as CI runs them, without building |

## Versions

| Command | Does |
|---|---|
| `task versions:check` | Report newer tool and Alpine package versions available |
| `task versions:bump` | Apply them to the `Dockerfile`, then regenerate the docs version tables |

See [Version pins](versions.md).

## Stage 1: Ansible

| Command | Does |
|---|---|
| `task stage1:test` | Static assertion of the kubeadm upgrade ordering. No cluster, no network. |
| `task stage1:ansible:syntax` | Parse every play and role without connecting |
| `task stage1:ansible:ping` | Verify SSH reachability of every host |
| `task stage1:ansible:playbook:check` | `--check --diff`. Connects, applies nothing. |
| `task stage1:ansible:playbook` | The full run |
| `task stage1:ansible:playbook:worker` | Workers only: `--limit 'localhost:agent' --skip-tags post_setup` |

All but `stage1:test` and `stage1:ansible:syntax` need SSH access. The two `playbook` targets prompt
for the become password.

## Stage 2: Terraform

| Command | Does |
|---|---|
| `task stage2:terraform:init` | `terraform init` and select the `homelab-k8s` workspace |
| `task stage2:terraform:init:upgrade` | Upgrade providers within their constraints, in the root and every child module |
| `task stage2:terraform:init:lock` | Regenerate provider lock files with `darwin_arm64` and `linux_amd64` hashes |
| `task stage2:terraform:plan` | |
| `task stage2:terraform:refresh` | Reconcile state with reality |
| `task stage2:terraform:apply` | |

!!! warning "`init:lock` must run inside the container"

    It first deletes darwin-built provider caches from the child modules, because they cannot be used
    inside a `linux_amd64` container. Producing both platforms' hashes is what lets the same lock
    file work on macOS and in CI.
