# Terraform variables

All 136 root input variables are declared in `stage2/variables.tf` and passed down to modules.
Child modules declare their own inputs and receive them from the root; none reads `TF_VAR_*`
directly, which is why every value is set in one place.

Values are supplied as `TF_VAR_*` environment variables, injected from
[Bitwarden](../operations/bitwarden-secrets.md) when you enter the tooling container. There is no
`terraform.tfvars`; `*.tfvars` is gitignored.

## Grouping

Variables are prefixed by the module that consumes them.

| Prefix | Count | Module |
|---|---|---|
| `gitlab_*` | 16 | [gitlab-platform](../stage2/gitlab-platform.md) |
| `litellm_*` | 14 | [litellm](../stage2/litellm.md) |
| `omniroute_*` | 13 | [omniroute-gateway](../stage2/omniroute-gateway.md) |
| `prometheus_*` | 12 | [monitoring](../stage2/monitoring.md) |
| `argocd_*` | 10 | [argocd](../stage2/argocd.md), [argocd-updater](../stage2/argocd-updater.md) |
| `minio_*` | 9 | [minio-object-storage](../stage2/minio-object-storage.md) |
| `auth_*` | 7 | [auth](../stage2/auth.md) |
| `elasticsearch_*`, `kibana_*` | 10 | [logging](../stage2/logging.md) |
| `wireguard_*`, `tailscale_*` | 9 | [vpn](../stage2/vpn.md) |
| `datadog_*` | 5 | [datadog](../stage2/datadog.md) |
| `cloudflare_*` | 5 | [cloudflare-tunnel](../stage2/cloudflare-tunnel.md) |
| `nginx_*`, `ingress_*` | 5 | [nginx](../stage2/nginx.md) |
| `kubecost_*` | 4 | [monitoring-kubecost](../stage2/monitoring-kubecost.md) |
| `cert_*` | 4 | [cert-manager-letsencrypt](../stage2/cert-manager-letsencrypt.md) |
| `longhorn_*` | 3 | [longhorn-storage](../stage2/longhorn-storage.md) |
| `kubernetes_*` | 3 | [kubernetes](../stage2/kubernetes.md) |
| `sealed_*` | 2 | [bitnami-sealed-secrets](../stage2/bitnami-sealed-secrets.md) |

Each module page documents the variables it actually consumes, with defaults. This page is the index;
the module page is the reference.

## Enable flags

The gates that decide whether a module is in the plan at all:

| Variable | Default | Module |
|---|---|---|
| `logging_module_enable` | `true` | logging |
| `argocd_image_updater_enable` | `false` | argocd-updater |
| `datadog_enable` | `false` | datadog |
| `cloudflare_tunnel_enable` | `false` | cloudflare-tunnel |
| `sealed_secrets_enable` | `true` | bitnami-sealed-secrets |
| `litellm_enable` | `false` | litellm |
| `omniroute_enable` | `false` | omniroute-gateway |
| `tailscale_enable` | `false` | vpn, Tailscale backend |
| `wireguard_enable` | `false` | vpn, WireGuard backend |

GitLab has no flag. It is gated on `host_machine_architecture == "amd64"`.

## Cross-cutting variables

| Variable | Used by |
|---|---|
| `host_machine_architecture` | Gates GitLab; also read by Stage 1 |
| `container_*` | Shared image registry and pull settings |

## Conventions

- snake_case, prefixed by consuming module.
- Every variable declares a `type`, a `description`, and a `default` where one is sensible.
- Validation blocks are used where a bad value would fail late and confusingly.
- Longer rationale goes in a comment above the block, not in the description.

Reading the file directly is often faster than any summary:

```bash
grep -A6 'variable "gitlab_' stage2/variables.tf
```
