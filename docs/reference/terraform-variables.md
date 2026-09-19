# Terraform variables

All 125 root input variables are declared in `stage2/variables.tf` and passed down to modules. Child modules declare their own inputs and receive them from the root; none reads `TF_VAR_*` directly, which is why every value is set in one place.

Values are supplied as `TF_VAR_*` environment variables, injected from [Bitwarden](../operations/bitwarden-secrets.md) when you enter the tooling container. There is no `terraform.tfvars`; `*.tfvars` is gitignored.

## Grouping

Variables are prefixed by the module that consumes them.

| Prefix | Count | Module |
|---|---|---|
| `gitlab_*` | 16 | [gitlab-platform](../stage2/gitlab-platform.md) |
| `litellm_*` | 13 | [litellm](../stage2/litellm.md) |
| `omniroute_*` | 12 | [omniroute-gateway](../stage2/omniroute-gateway.md) |
| `prometheus_*` | 11 | [monitoring](../stage2/monitoring.md) |
| `argocd_*` | 10 | [argocd](../stage2/argocd.md), [argocd-updater](../stage2/argocd-updater.md) |
| `elasticsearch_*`, `kibana_*` | 9 | [logging](../stage2/logging.md) |
| `minio_*` | 8 | [minio-object-storage](../stage2/minio-object-storage.md) |
| `wireguard_*`, `tailscale_*` | 8 | [tailscale](../stage2/tailscale.md), [wireguard](../stage2/wireguard.md) |
| `auth_*` | 6 | [auth](../stage2/auth.md) |
| `datadog_*` | 5 | [datadog](../stage2/datadog.md) |
| `cloudflare_*` | 5 | [cloudflare-tunnel](../stage2/cloudflare-tunnel.md) |
| `kubernetes_*` | 4 | [kubernetes](../stage2/kubernetes.md) |
| `kubecost_*` | 3 | [monitoring-kubecost](../stage2/monitoring-kubecost.md) |
| `cert_*` | 2 | [cert-manager-letsencrypt](../stage2/cert-manager-letsencrypt.md) |
| `istio_*` | 2 | [istio-gateway](../stage2/istio-gateway.md) |
| `longhorn_*` | 2 | [longhorn-storage](../stage2/longhorn-storage.md) |
| `sealed_*` | 2 | [bitnami-sealed-secrets](../stage2/bitnami-sealed-secrets.md) |
| `ingress_*` | 1 | [gitlab-platform](../stage2/gitlab-platform.md) |

Each module page documents the variables it actually consumes, with defaults. This page is the index; the module page is the reference.

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
| `hostname_prefix` | Tailnet machine names in the [vpn](../stage2/tailscale.md) module. Deliberately not prefixed by a module: Stage 0 and Stage 1 read the same value, so every device sorts together in the tailnet |

## Conventions

- snake_case, prefixed by consuming module.
- Every variable declares a `type`, a `description`, and a `default` where one is sensible.
- Validation blocks are used where a bad value would fail late and confusingly.
- Longer rationale goes in a comment above the block, not in the description.

Reading the file directly is often faster than any summary:

```bash
grep -A6 'variable "gitlab_' stage2/variables.tf
```
