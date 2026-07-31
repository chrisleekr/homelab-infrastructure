# Reference

| Page | Contents |
|---|---|
| [Version pins](versions.md) | Generated tables of every pinned tool and cluster component |
| [Task commands](tasks.md) | Every `task` target |
| [Repository layout](repository-layout.md) | What lives where |
| [Terraform variables](terraform-variables.md) | `stage2/variables.tf` grouped by module |

## Which file is the source of truth

This is the question that causes the most confusion, so it gets a table.

| Kind of version | Source of truth | Changed with |
|---|---|---|
| Operator tools: kubectl, helm, terraform, taskfile, trivy, tflint, bws | `ARG *_VERSION` in `Dockerfile` | `task versions:bump` |
| Cluster components: kubeadm, kubelet, containerd, runc, CNI, crictl, nerdctl, Cilium, pluto, minikube, k3s | `*_version` in `stage1/inventories/inventory.yml` | edit, then re-run Stage 1 |
| Helm charts | the individual `helm_release` resources under `stage2/` | edit, then `terraform apply` |
| Alpine packages | pinned `apk` lines in `Dockerfile` | `task versions:bump` |

[Version pins](versions.md) is generated from the first two by `scripts/sync-versions.sh` and
verified in CI. Editing those tables by hand does nothing. The next run overwrites them.

!!! note "kubectl is pinned twice, on purpose"

    Once for the operator's client (`ARG KUBECTL_VERSION`) and once for the nodes
    (`kubectl_version`). `scripts/sync-versions.sh` asserts they agree and fails outright if they
    diverge, so a silent client/server skew cannot reach the docs.
