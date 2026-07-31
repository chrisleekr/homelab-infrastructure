# Platform (Stage 2)

Stage 2 is Terraform. It assumes a working Kubernetes cluster from
[Stage 1](../stage1/index.md) and deploys 19 modules onto it.

Every module is a directory under `stage2/`, wired together in `stage2/main.tf`. All input variables
live in the root `stage2/variables.tf` and are passed down, so a module never reads a variable
directly.

## Always-on modules

These have no `count`, so they deploy on every apply.

| Module | Deploys |
|---|---|
| [Kubernetes](kubernetes.md) | CoreDNS configuration, Prometheus CRDs |
| [NGINX Ingress](nginx.md) | Ingress controller, fronted by MetalLB |
| [Cert-Manager](cert-manager-letsencrypt.md) | TLS certificates from Let's Encrypt |
| [Longhorn](longhorn-storage.md) | Distributed block storage, the default StorageClass |
| [MinIO](minio-object-storage.md) | S3-compatible object storage |
| [Monitoring](monitoring.md) | Prometheus, Grafana, AlertManager, ElastAlert2 |
| [Kubecost](monitoring-kubecost.md) | Cluster cost attribution |
| [OAuth2 Proxy](auth.md) | Auth0-backed authentication in front of the web UIs |
| [ArgoCD](argocd.md) | GitOps continuous deployment |
| [VPN](vpn.md) | Tailscale and WireGuard |
| [Stakater Reloader](stakater-reloader.md) | Restarts workloads when a Secret or ConfigMap changes |

## Gated modules

Controlled by an enable flag. The Terraform idiom is `count = var.<name>_enable ? 1 : 0`, so a
disabled module is simply not in the plan.

| Module | Gate | Default |
|---|---|---|
| [GitLab Platform](gitlab-platform.md) | `host_machine_architecture == "amd64"` | auto, AMD64 only |
| [Logging](logging.md) | `logging_module_enable` | `true` |
| [ArgoCD Image Updater](argocd-updater.md) | `argocd_image_updater_enable` | `false` |
| [Datadog](datadog.md) | `datadog_enable` | `false` |
| [Cloudflare Tunnel](cloudflare-tunnel.md) | `cloudflare_tunnel_enable` | `false` |
| [Sealed Secrets](bitnami-sealed-secrets.md) | `sealed_secrets_enable` | `true` |
| [LiteLLM](litellm.md) | `litellm_enable` | `false` |
| [OmniRoute](omniroute-gateway.md) | `omniroute_enable` | `false` |

The [VPN](vpn.md) module has no module-level gate, so it is always in the plan and its `vpn`
namespace is always created. The two backends are gated per resource by `tailscale_enable` and
`wireguard_enable`, both `false` by default and independent of each other.

!!! warning "GitLab is AMD64 only"

    `registry.gitlab.com/gitlab-org/build/cng/kubectl` publishes no ARM64 image. On an ARM64 control
    plane the GitLab module is skipped entirely, which also removes ArgoCD's `depends_on` source.

## Ordering

Modules do not deploy in file order. See the [dependency graph](dependency-graph.md) for the actual
`depends_on` DAG and why the ordering matters.
