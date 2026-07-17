# Bitwarden Secrets Manager Setup

This repo loads all secrets and configuration from **Bitwarden Secrets Manager** at container
start, instead of a plaintext `.env`. The only value stored locally is a Bitwarden access token.

## Why

- Secret **values** never sit in a file on disk. The gitignored `.env` holds just the access token.
- One central store, rotatable and revocable, shared across machines.
- `bws run` injects each secret as an environment variable named exactly as the secret, so Terraform
  (`TF_VAR_*`, `TF_TOKEN_app_terraform_io`) and Ansible (`lookup('env', ...)`) work unchanged.

## How it works

When you enter the container (`task docker:exec`), `scripts/container/root/.bashrc` sources the loader
`scripts/container/root/bws-load.sh`, which:

1. Reads `BWS_ACCESS_TOKEN` (+ `BWS_PROJECT_ID`) from the mounted `/srv/.env`.
2. Re-runs bash under `bws run --project-id <id> -- bash`, which authenticates to Bitwarden cloud and
   injects every secret in the project as a native environment variable.
3. A `BWS_LOADED` guard prevents the re-run from recursing. Inside the injected shell the access
   token is unset, so it is not inherited by terraform/ansible or any subprocess.

If Bitwarden is unreachable or the token is bad, you still get a plain (secret-less) shell with a
warning — no lockout. `BWS_SKIP=1` bypasses the auto-load entirely.

**Reload without restarting.** After you add or change a secret in Bitwarden, refresh the current shell
in place — no need to exit the container:

```bash
bws-load        # clears the guard and re-execs bash, pulling the latest secrets
```

For a one-off command with secrets injected (host or CI, non-interactive), wrap it with `bws run`:

```bash
bws run --project-id <id> -- terraform -chdir=stage2 plan
```

> **Important:** Bitwarden **cloud** is required. Vaultwarden does **not** implement Secrets Manager.
> The free tier covers this repo (unlimited secrets, 3 projects, 3 machine accounts).


## 1. Install the `bws` CLI locally

You need `bws` on your machine to create and manage secrets. There is no Homebrew formula; use the
official install script (it detects platform/arch, downloads, and validates the checksum):

```bash
curl -fsSL https://bws.bitwarden.com/install | sh
bws --version                            # -> bws 2.1.0
```

Pin a version with `BWS_VERSION=2.1.0 curl -fsSL https://bws.bitwarden.com/install | sh`. Or download a
binary directly from the [releases page](https://github.com/bitwarden/sdk-sm/releases) (macOS:
`bws-macos-universal-*.zip`; Linux: `bws-<arch>-unknown-linux-musl-*.zip`) and put it on `PATH`.

(The container already has `bws` baked into its image, so you only need it locally for management.)

## 2. Provision the backend (one-time)

The project `homelab-infrastructure` already exists. To (re)create the pieces on a fresh org:

1. **Enable Secrets Manager** on your Bitwarden organization.
2. **Create a project**, e.g. `homelab-infrastructure`. Find its id with `bws project list`.
3. **Create a machine account** and grant it **`can read`** on the project.
4. **Create an access token** for that machine account. Treat it like a password.

## 3. Configure your local `.env`

Copy the template and fill in only the two Bitwarden values (get the project id from
`bws project list`):

```bash
cp .env.example .env
# then edit .env:
#   BWS_ACCESS_TOKEN=<your machine-account access token>
#   BWS_PROJECT_ID=<id from `bws project list`>
```

`.env` is gitignored. Neither value is ever committed.

**Optional hardening (no token in any file):** leave `BWS_ACCESS_TOKEN` out of `.env`, keep it in your
host keychain/`pass`, and pass it in at run time with `docker run -e BWS_ACCESS_TOKEN ...`.

## 4. Create the secrets

Load your ids first so the project id is never typed inline:

```bash
set -a; . .env; set +a
```

**Web UI:** Secrets Manager → project `homelab-infrastructure` → *New secret*. Name = the env var,
Value = the value, assign to the project.

**CLI:**

```bash
bws secret create <NAME> "<VALUE>" "$BWS_PROJECT_ID"

# examples:
bws secret create k3s_token "$(openssl rand -base64 64 | tr -d '\n')" "$BWS_PROJECT_ID"
bws secret create TF_VAR_prometheus_grafana_domain "grafana.chrislee.local" "$BWS_PROJECT_ID"
```

> **Store literal values.** Bitwarden does not expand `${...}`. Resolve any interpolation before saving,
> e.g. `grafana.${domain_host}` → `grafana.chrislee.local`, `${server_ssh_host}` → `192.168.1.100`.

> JSON values (`worker_hosts_json`, `etc_hosts_json`, `worker_default_taints`) are stored **raw** — no
> `\"` escaping. `bws run` injects them natively, which is why the old godotenv escaping rule is gone.

> Never name a secret after a shell-sensitive variable (`PATH`, `LD_PRELOAD`, `LD_LIBRARY_PATH`,
> `BASH_ENV`, `ENV`, `IFS`). These are injected into the shell and can enable code execution. Only
> the documented `TF_VAR_*`, `TF_TOKEN_*`, and lowercase config names below are expected.

## 5. Variable reference

**Every** variable from the old `.env.sample` becomes a secret in the project (name = env var). 🔑 marks
sensitive values; the rest is config. Store literal values — example values use the old template
defaults, so substitute your own. **Gate** = only needed when that module's `*_enable` flag is `true`.

### Global / Terraform Cloud

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_TOKEN_app_terraform_io` | 🔑 | Terraform Cloud → User Settings → Tokens | Auth to Terraform Cloud remote state; needed before `terraform init` |
| `host_machine_architecture` | | `amd64` (or `arm64`) | Build/target architecture |
| `domain_host` | | `chrislee.local` | Base domain all service hostnames derive from |

### Stage 1 — cluster / Ansible

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `kubernetes_cluster_type` | | `kubeadm` (or `k3s` / `minikube`) | Which cluster provisioner to run |
| `server_ssh_host` | | `192.168.1.100` | Control-plane node IP |
| `server_ssh_user` | 🔑 | your node SSH username | SSH login user for provisioning |
| `server_ssh_port` | | `2222` | SSH port (must not be 22) |
| `worker_hosts_json` | | `[]` or raw JSON array | Worker node definitions (raw JSON, no escaping) |
| `worker_default_taints` | | `[{"key":"node.homelab/class","value":"low-power","effect":"NoSchedule"}]` | Default taint for workers without their own |
| `k3s_extra_server_args` | | (empty) | Extra args for the k3s server |
| `k3s_token` | 🔑 | `openssl rand -base64 64 \| tr -d '\n'` | k3s node join secret |
| `sshd_port` | | `2222` | Hardened sshd port (matches `server_ssh_port`) |
| `wireguard_port` | | `51820` | WireGuard listen port |
| `docker_default_data_path` | | `/var/lib/docker` | Docker data root |
| `etc_hosts_json` | | `[]` or raw JSON array | Extra `/etc/hosts` entries (raw JSON) |

### Stage 2 — Kubernetes / ingress

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_ingress_enable_tls` | | `true` | Generate TLS certs when true |
| `TF_VAR_host_machine_architecture` | | `amd64` | Passthrough of `host_machine_architecture` |
| `TF_VAR_kubernetes_override_ip` | | `192.168.1.100` | Cluster external IP override |
| `TF_VAR_kubernetes_override_domains` | | space-separated domain list (flattened) | Domains routed to the cluster |

### Stage 2 — Nginx

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_nginx_service_loadbalancer_ip` | | `192.168.1.100` | LoadBalancer IP for the ingress |
| `TF_VAR_nginx_frontend_basic_auth_base64` | 🔑 | `htpasswd -nb user password \| openssl base64` | HTTP basic-auth gate on the frontend |
| `TF_VAR_nginx_client_max_body_size` | | `10M` | Max request body size |
| `TF_VAR_nginx_client_body_buffer_size` | | `10M` | Request body buffer size |

### Stage 2 — Cert Manager

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_cert_manager_acme_email` | | `chris@chrislee.local` | ACME registration email |
| `TF_VAR_cert_manager_ingress_class` | | `nginx` | Ingress class for ACME solver |
| `TF_VAR_cert_manager_host_alias_ip` | | `192.168.1.100` | Hairpin-NAT host alias IP |
| `TF_VAR_cert_manager_host_alias_hostnames` | | comma-separated hostnames (flattened) | Hairpin-NAT host aliases |

### Stage 2 — Longhorn

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_longhorn_default_settings_default_data_path` | | `/var/lib/longhorn` | Longhorn data path |
| `TF_VAR_longhorn_ingress_class_name` | | `nginx` | Ingress class |
| `TF_VAR_longhorn_ingress_host` | | `k8s.chrislee.local` | Longhorn UI host |

### Stage 2 — MinIO

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_minio_tenant_pools_size` | | `100Gi` | Tenant pool capacity |
| `TF_VAR_minio_tenant_ingress_class_name` | | `nginx` | Ingress class |
| `TF_VAR_minio_tenant_ingress_api_host` | | `minio.chrislee.local` | S3 API host |
| `TF_VAR_minio_tenant_ingress_console_host` | | `minio-console.chrislee.local` | Console host |

### Stage 2 — GitLab

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_gitlab_global_hosts_domain` | | `chrislee.local` | GitLab base domain |
| `TF_VAR_gitlab_global_hosts_host_suffix` | | (empty) | Optional host suffix |
| `TF_VAR_gitlab_global_hosts_external_ip` | | `192.168.1.100` | External IP |
| `TF_VAR_gitlab_global_ingress_class` | | `nginx` | Ingress class |
| `TF_VAR_gitlab_global_ingress_provider` | | `nginx` | Ingress provider |
| `TF_VAR_gitlab_certmanager_issuer_email` | | `chris@chrislee.local` | Issuer email |
| `TF_VAR_gitlab_postgresql_primary_persistence_size` | | `20Gi` | Postgres volume |
| `TF_VAR_gitlab_redis_master_persistence_size` | | `20Gi` | Redis volume |
| `TF_VAR_gitlab_gitaly_persistence_size` | | `50Gi` | Gitaly volume. Backs a StatefulSet claim template, which is immutable, so this must match the existing volume |
| `TF_VAR_gitlab_toolbox_persistence_size` | | `20Gi` | Toolbox volume |
| `TF_VAR_gitlab_toolbox_backups_cron_persistence_size` | | `30Gi` | Backup staging volume |
| `TF_VAR_gitlab_runner_authentication_token` | 🔑 | GitLab → Admin → CI/CD → Runners → New instance runner (allow untagged) | Registers the CI runner |
| `TF_VAR_gitlab_minio_host` | | `minio.chrislee.local` | Object storage host |
| `TF_VAR_gitlab_minio_endpoint` | | `https://minio.chrislee.local` | Object storage endpoint |
| `TF_VAR_gitlab_minio_use_https` | | `True` | Use HTTPS to object storage |

### Stage 2 — Prometheus Stack

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_prometheus_alertmanager_domain` | | `alertmanager.chrislee.local` | Alertmanager host |
| `TF_VAR_prometheus_grafana_domain` | | `grafana.chrislee.local` | Grafana host |
| `TF_VAR_prometheus_ingress_class_name` | | `nginx` | Ingress class |
| `TF_VAR_prometheus_prometheus_domain` | | `prometheus.chrislee.local` | Prometheus host |
| `TF_VAR_prometheus_persistence_size` | | `10Gi` | Prometheus volume |
| `TF_VAR_prometheus_alertmanager_slack_channel` | | `notification` | Slack channel for alerts |
| `TF_VAR_prometheus_alertmanager_slack_credentials` | 🔑 | api.slack.com/apps → Install App → Bot User OAuth Token | Alertmanager → Slack delivery |
| `TF_VAR_prometheus_minio_job_bearer_token` | 🔑 | `mc admin prometheus generate minio` | Scrape MinIO cluster metrics |
| `TF_VAR_prometheus_minio_job_node_bearer_token` | 🔑 | `mc admin prometheus generate minio node` | Scrape MinIO node metrics |
| `TF_VAR_prometheus_minio_job_bucket_bearer_token` | 🔑 | `mc admin prometheus generate minio bucket` | Scrape MinIO bucket metrics |
| `TF_VAR_prometheus_minio_job_resource_bearer_token` | 🔑 | `mc admin prometheus generate minio resource` | Scrape MinIO resource metrics |

### Stage 2 — Logging / Elasticsearch / Kibana

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_logging_module_enable` | | `true` | Enable the logging module |
| `TF_VAR_elasticsearch_storage_size` | | `10Gi` | Elasticsearch volume |
| `TF_VAR_kibana_ingress_class_name` | | `nginx` | Ingress class |
| `TF_VAR_kibana_domain` | | `kibana.chrislee.local` | Kibana host |

### Stage 2 — Kubecost

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_kubecost_ingress_host` | | `cost.chrislee.local` | Kubecost host |
| `TF_VAR_kubecost_ingress_class_name` | | `nginx` | Ingress class |
| `TF_VAR_kubecost_token` | 🔑 | generated at kubecost.com/install | Alerts / trial features |

### Stage 2 — Tailscale (gate: `TF_VAR_tailscale_enable`)

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_tailscale_enable` | | `false` | Enable Tailscale |
| `TF_VAR_tailscale_auth_key` | 🔑 | tailscale.com/kb/1085/auth-keys | Node auth to the Tailnet |
| `TF_VAR_tailscale_advertise_routes` | | `192.86.0.0/24` | Subnet routes advertised |
| `TF_VAR_tailscale_hostname` | | `tailscale-kubernetes` | Tailnet hostname |

### Stage 2 — WireGuard (gate: `TF_VAR_wireguard_enable`)

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_wireguard_enable` | | `false` | Enable WireGuard |
| `TF_VAR_wireguard_ingress_host` | | `vpn.chrislee.local` | VPN host |
| `TF_VAR_wireguard_port` | | `51820` | Listen port |

### Stage 2 — ArgoCD

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_argocd_apps_repo_url` | | (empty, or repo URL) | Root apps repo for ApplicationSet |
| `TF_VAR_argocd_config_repositories_json_encoded` | 🔑 | JSON array of repo creds; `[]` if none | Repo connection creds (may embed tokens) |
| `TF_VAR_argocd_domain` | | `argocd.chrislee.local` | ArgoCD host |
| `TF_VAR_argocd_rbac_policy_default` | | `role:readonly` | Default RBAC role |
| `TF_VAR_argocd_ssh_known_hosts_base64` | 🔑 | `ssh-keyscan <host> \| base64` (optional) | Verify SSH git repos |
| `TF_VAR_argocd_rbac_policy_csv` | | multi-line RBAC CSV | Extra RBAC policy rules |

### Stage 2 — ArgoCD Image Updater (gate: `TF_VAR_argocd_image_updater_enable`)

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_argocd_image_updater_enable` | | `false` | Enable image updater |
| `TF_VAR_container_registry_prefix` | | `registry.chrislee.local` | Registry prefix |
| `TF_VAR_container_registry_api_url` | | `https://registry.chrislee.local` | Registry API URL |
| `TF_VAR_container_registry_credentials` | 🔑 | GitLab deploy token, `read_registry` scope, as `username:token` | Pull images from the registry |
| `TF_VAR_argocd_apps_git_username` | | `argocd-image-updater` | Git user for write-back |
| `TF_VAR_argocd_apps_git_password` | 🔑 | GitLab project access token, `write_repository` scope | Write image-tag bumps to argocd-apps repo |

### Stage 2 — OAuth2 Proxy + Auth0

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_auth_ingress_class_name` | | `nginx` | Ingress class |
| `TF_VAR_auth_oauth2_proxy_host` | | `auth.chrislee.local` | OAuth2 proxy host |
| `TF_VAR_auth_oauth2_proxy_cookie_domains` | | `[".chrislee.local"]` | Cookie domains |
| `TF_VAR_auth_oauth2_proxy_whitelist_domains` | | `["*.chrislee.local"]` | Redirect whitelist |
| `TF_VAR_auth_auth0_domain` | 🔑 | Auth0 dashboard → Application settings | Auth0 tenant for SSO |
| `TF_VAR_auth_auth0_client_id` | 🔑 | Auth0 dashboard → Application settings | Auth0 app identifier |
| `TF_VAR_auth_auth0_client_secret` | 🔑 | Auth0 dashboard → Application settings | Auth0 app secret; gates all web services |

### Stage 2 — Datadog (gate: `TF_VAR_datadog_enable`)

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_datadog_enable` | | `false` | Enable Datadog |
| `TF_VAR_datadog_site` | | `datadoghq.com` | Datadog site |
| `TF_VAR_datadog_cluster_name` | | `homelab` | Cluster name tag |
| `TF_VAR_datadog_api_key` | 🔑 | Datadog → Org Settings → API Keys | Agent ingestion |
| `TF_VAR_datadog_app_key` | 🔑 | Datadog → Org Settings → Application Keys | API/app-scoped access |

### Stage 2 — LLM Gateway (gate: `TF_VAR_llmgateway_enable`)

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_llmgateway_enable` | | `false` | Enable LLM Gateway |
| `TF_VAR_llmgateway_domain` | | `llm.chrislee.local` | Gateway host |
| `TF_VAR_llmgateway_ingress_class_name` | | `nginx` | Ingress class |
| `TF_VAR_llmgateway_storage_size` | | `10Gi` | Storage size |
| `TF_VAR_llmgateway_storage_class_name` | | `longhorn` | Storage class |
| `TF_VAR_llmgateway_auth_secret` | 🔑 | `openssl rand -hex 32` | Session/auth signing secret |
| `TF_VAR_llmgateway_image_tag` | | `latest` | Image tag |
| `TF_VAR_llmgateway_replicas` | | `1` | Replica count |
| `TF_VAR_llmgateway_admin_emails` | | `chris@chrislee.local` | Admin emails |

### Stage 2 — Cloudflare Tunnel (gate: `TF_VAR_cloudflare_tunnel_enable`)

| Variable | | Value / how to obtain | Purpose |
|---|---|---|---|
| `TF_VAR_cloudflare_tunnel_enable` | | `false` | Enable the tunnel |
| `TF_VAR_cloudflare_tunnel_token` | 🔑 | Cloudflare → Zero Trust → Networks → Tunnels → copy `--token` `eyJ…` | cloudflared connector auth |
| `TF_VAR_cloudflare_tunnel_chart_version` | | `0.1.2` | Helm chart version |
| `TF_VAR_cloudflare_tunnel_image_tag` | | (empty) | cloudflared image tag (empty = chart default) |
| `TF_VAR_cloudflare_tunnel_replica_count` | | `2` | Replica count |

## 6. Manage secrets day-to-day

```bash
set -a; . .env; set +a

bws secret list                       # list all (names + ids)
bws secret get <secret-id>            # read one
bws secret edit <secret-id> --value "<new value>"
bws secret delete <secret-id>
```

After editing a secret, run `bws-load` inside the container to pull the change into your current shell
(see "Reload without restarting" above).

**Rotate the access token:** create a new token on the machine account, update `.env`, then revoke the
old one. **Least privilege:** the machine account only needs `can read`.

## 7. Verify

```bash
task docker:exec                      # enter the container; .bashrc auto-injects secrets

# inside the container:
echo "$TF_VAR_prometheus_grafana_domain"     # -> grafana.chrislee.local (flattened, not ${domain_host})
task stage2:terraform:plan                   # authenticates via TF_TOKEN_app_terraform_io
task stage1:ansible:ping                     # reaches the cluster via injected SSH vars
```

Run secret-consuming tasks **inside the container**. Host-side terraform is only for no-secret ops
(`terraform providers lock`, `init -backend=false`, `fmt`, `validate`). For CI/scripted runs, call
`bws run -- <command>` directly, since `.bashrc` only auto-loads for interactive shells.
