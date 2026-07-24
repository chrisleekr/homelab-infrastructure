# OmniRoute

Self-hosted [OmniRoute](https://github.com/diegosouzapw/OmniRoute) AI gateway: an OpenAI-compatible
`/api/v1` endpoint in front of many upstream providers, plus a management dashboard (served under
`/dashboard`) behind oauth2-proxy.

Disabled by default. Set `omniroute_enable = true` (or `TF_VAR_omniroute_enable`) to deploy.
Independent of the `litellm` module; both can run at once.

## What this module creates

| Resource | Name | Notes |
|---|---|---|
| Namespace | `omniroute` | |
| Secret | `omniroute-auth` | `JWT_SECRET`, `API_KEY_SECRET`, `INITIAL_PASSWORD`, `STORAGE_ENCRYPTION_KEY`, mounted with `envFrom` |
| Helm release | `omniroute` | Chart `omniroute`, from `https://chrisleekr.github.io/helm-charts` |
| Ingress | `omniroute-api` | `var.omniroute_public_paths` (default `/api/v1`), open, SSE-safe |
| Ingress | `omniroute-ui` | Catch-all `/`, behind oauth2-proxy, carries the cert-manager annotation |

The chart owns the Service (`omniroute:20128`), the PVC (`omniroute-data`), the ServiceAccount
(`automountServiceAccountToken: false`), and a single-replica Deployment with a `Recreate` update
mode. None of those are overridden here.

## Design notes

**All 4 auth keys in a module-owned Secret.** The chart can generate `JWT_SECRET` / `API_KEY_SECRET`
itself, but only during a live `helm install/upgrade` via a cluster `lookup`. Any client-side render
(`helm template`, ArgoCD/Flux without server-side apply) cannot see the existing Secret and mints
NEW values every sync, which makes stored provider keys unreadable. The module therefore sets
`auth.existingSecret: omniroute-auth` and supplies all four keys from Terraform, so the chart skips
its own `secret.yaml` entirely and no credential is written into the Helm values string.

**Inverted split ingress.** OmniRoute serves its dashboard and all non-API routes from the host root
with no gate of its own, so without oauth2-proxy the console HTML would be public. The chart's single
Ingress is disabled and the module writes two on the same host:

- `omniroute-api` — open, for `var.omniroute_public_paths` (default `/api/v1`). No oauth2-proxy:
  OmniRoute enforces `REQUIRE_API_KEY` on `/api/v1` itself, and an HTTP redirect to an SSO login
  page would break SDK clients. Carries the SSE annotations (`proxy-http-version: "1.1"`,
  `proxy-buffering: "off"`) that make token streaming actually stream.
- `omniroute-ui` — the catch-all `/`, behind oauth2-proxy. It also captures any `/api` path not in
  `omniroute_public_paths`, so provider callbacks and management routes stay gated.

nginx matches the longest prefix first, so `/api/v1` beats `/` and API clients always reach the open
Ingress. This is the mirror image of the litellm module, where `/` is the open API and listed paths
are gated.

Because `/api/v1` is unauthenticated at the edge, the module forces
`extraConfig.REQUIRE_API_KEY: "true"` so OmniRoute requires an API key on every proxy call.
`REQUIRE_API_KEY` is resolved with a database override ahead of the environment value, so never
disable it from the dashboard while `/api/v1` is served open, or the whole prefix becomes anonymous.

**Admin subpaths gated as defense in depth.** The open `/api/v1` prefix also carries OmniRoute's
management routes (`/api/v1/management`, `/api/v1/agents`, `/api/v1/accounts`,
`/api/v1/registered-keys`), which OpenAI-compatible clients never call. `var.omniroute_gated_api_paths`
pulls those specific subpaths back onto the oauth2-gated Ingress; nginx longest-prefix routes them
there ahead of the open `/api/v1`, so they require an oauth2 session on top of the API key while
model calls stay open. The dashboard's own browser calls to them still pass, carrying the oauth2
cookie. Set the variable to `[]` to disable the extra gating. The exact admin subpath set is
app-version dependent; re-verify it against a running container.

Both Ingresses share one host and one TLS secret, and only `omniroute-ui` carries
`cert-manager.io/cluster-issuer`. Annotating both would create competing Certificates for the same
secret.

**Residual public surface.** Only the paths in `omniroute_public_paths` are unauthenticated.
Anything else falls through to the gated Ingress. If you enable web-cookie providers (`gemini-web`,
`claude-web`) or external OAuth/webhook callbacks, those callback paths must be added to
`omniroute_public_paths` or the provider handshake fails behind the login redirect:

| Candidate path | When to add it |
|---|---|
| `/api/v1` | Always (default). The OpenAI-compatible API base path |
| `/api/oauth`, `/api/webhooks` | Provider OAuth or webhook callbacks that must reach the app unauthenticated |
| `/.well-known` | cert-manager HTTP-01 solver, or provider discovery documents |

The exact set is app-version dependent; re-verify it against a running container before widening it.

**Single-writer store.** OmniRoute persists everything in SQLite on the PVC. The chart hard-pins one
replica and a `Recreate` update mode, and the module leaves both alone: two pods on one PVC corrupt
the database. There is no HPA for the same reason.

## Variables

| Variable | Type | Default | Purpose |
|---|---|---|---|
| `omniroute_enable` | bool | `false` | Module gate. Everything below is inert while false |
| `omniroute_domain` | string | `omniroute.chrislee.local` | Single host serving `/api/v1` and the dashboard |
| `omniroute_ingress_class_name` | string | `nginx` | Ingress class for both Ingresses |
| `omniroute_ingress_enable_tls` | bool | `true` | Wired from the root `ingress_enable_tls` |
| `omniroute_public_paths` | list(string) | `["/api/v1"]` | Paths routed to the open API Ingress. Omissions fall through to oauth2-proxy |
| `omniroute_gated_api_paths` | list(string) | `["/api/v1/management", "/api/v1/agents", "/api/v1/accounts", "/api/v1/registered-keys"]` | Admin subpaths under `/api/v1` pulled back behind oauth2-proxy. `[]` disables |
| `omniroute_chart_version` | string | `0.1.1` | `omniroute` chart pin. Bump with the image tag |
| `omniroute_image_tag` | string | `""` | `diegosouzapw/omniroute` tag. Empty uses the chart appVersion; use `-web` for web-cookie providers |
| `omniroute_storage_class_name` | string | `longhorn` | SQLite PVC storage class |
| `omniroute_storage_size` | string | `5Gi` | SQLite PVC size |
| `omniroute_initial_password` | string, sensitive | `""` | First-boot dashboard password, min 12 chars |
| `omniroute_jwt_secret` | string, sensitive | `""` | Session-signing key, min 32 chars. Rotatable |
| `omniroute_api_key_secret` | string, sensitive | `""` | Encrypts stored provider keys, min 32 chars. Write once |
| `omniroute_storage_encryption_key` | string, sensitive | `""` | Encrypts the DB at rest, min 32 chars. Write once |
| `auth_oauth2_proxy_host` | string | `""` | oauth2-proxy host guarding the dashboard |

The four credential variables default to `""` so the module stays valid while disabled. Their
`validation` blocks reject a malformed non-empty value; `precondition` blocks in `secrets.tf` make
them mandatory once `omniroute_enable = true`.

## Secrets

Supplied through Bitwarden Secrets Manager as `TF_VAR_*`; see
[docs/bitwarden-secrets-setup.md](../../docs/bitwarden-secrets-setup.md).

| Variable | How to generate |
|---|---|
| `omniroute_initial_password` | `openssl rand -base64 24` (a strong password) |
| `omniroute_jwt_secret` | `openssl rand -hex 32` |
| `omniroute_api_key_secret` | `openssl rand -hex 32` |
| `omniroute_storage_encryption_key` | `openssl rand -hex 32` |

> `omniroute_api_key_secret` encrypts every provider credential and `omniroute_storage_encryption_key`
> encrypts the database at rest. **Write both once and never rotate them** — rotating either makes
> already-stored data permanently unreadable. `omniroute_jwt_secret` only signs sessions and may be
> rotated (it logs everyone out).

## Operations

```bash
kubectl -n omniroute get pods,pvc,ingress,secret

# /api/monitoring/health is the in-pod liveness/readiness probe. It is NOT in
# omniroute_public_paths, so from the edge it falls through to the oauth2 gate and returns a login
# redirect. Reach it directly instead:
kubectl -n omniroute port-forward svc/omniroute 20128:20128
curl -sS http://127.0.0.1:20128/api/monitoring/health

# The open API surface, reachable from outside with an API key:
curl -sS https://$DOMAIN/api/v1/models -H "Authorization: Bearer $API_KEY"
```

## Caveats

- **The PVC holds the only copy of state.** Providers, keys, and settings live in SQLite on the
  `omniroute-data` PVC. Setting `omniroute_enable = false` deletes the Namespace, and that is what
  reaps the PVC and the data. Back up before disabling.
- **Write-once keys.** Rotating `omniroute_api_key_secret` or `omniroute_storage_encryption_key`
  after providers have been added makes every stored credential permanently unreadable. Generate
  them once and keep them in Bitwarden.
- **TLS on a `.local` domain never issues.** `letsencrypt-prod` cannot complete an HTTP-01 challenge
  for `omniroute.chrislee.local`. Certificates only issue once a real public domain is set. This is
  the repo-wide pattern, not specific to this module.
- **`-web` image flavor.** Web-cookie providers (`gemini-web`, `claude-web`, `claude-turnstile`)
  need the `-web` image; set `omniroute_image_tag` to e.g. `3.8.48-web`, and add their callback
  paths to `omniroute_public_paths`.
- **Chart and image versions move together.** Bump `omniroute_chart_version` and
  `omniroute_image_tag` as a pair.
