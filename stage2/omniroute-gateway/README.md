# OmniRoute

Self-hosted [OmniRoute](https://github.com/diegosouzapw/OmniRoute) AI gateway: an OpenAI-compatible
API endpoint (`/v1`, with `/api/v1` serving the same handlers) in front of many upstream providers,
plus a management dashboard (served under `/dashboard`) behind oauth2-proxy.

Disabled by default. Set `omniroute_enable = true` (or `TF_VAR_omniroute_enable`) to deploy.
Independent of the `litellm` module; both can run at once.

## What this module creates

| Resource | Name | Notes |
|---|---|---|
| Namespace | `omniroute` | |
| Secret | `omniroute-auth` | `JWT_SECRET`, `API_KEY_SECRET`, `INITIAL_PASSWORD`, `STORAGE_ENCRYPTION_KEY`, mounted with `envFrom` |
| Helm release | `omniroute` | Chart `omniroute`, from `https://chrisleekr.github.io/helm-charts` |
| Ingress | `omniroute-api` | `var.omniroute_public_paths` (default `/api/v1` and `/v1`), open, SSE-safe |
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

- `omniroute-api` — open, for `var.omniroute_public_paths` (default `/api/v1` and `/v1`). No
  oauth2-proxy: OmniRoute enforces `REQUIRE_API_KEY` on the API itself, and an HTTP redirect to an
  SSO login page would break SDK clients. Carries the SSE annotations (`proxy-http-version: "1.1"`,
  `proxy-buffering: "off"`) that make token streaming actually stream.
- `omniroute-ui` — the catch-all `/`, behind oauth2-proxy. It also captures any `/api` path not in
  `omniroute_public_paths`, so provider callbacks and management routes stay gated.

Deploying multiple Ingress objects per host is the documented way to mix open and authenticated
paths: `auth-url`/`auth-signin` are per-Ingress-object annotations, so a single Ingress cannot gate
some of its paths and not others
([ingress-nginx external OAUTH](https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/)).
nginx matches the longest prefix first, so `/api/v1` and `/v1` beat `/` and API clients always reach
the open Ingress. This is the mirror image of the litellm module, where `/` is the open API and
listed paths are gated.

Matching is element-wise, per the
[Ingress spec](https://kubernetes.io/docs/reference/kubernetes-api/service-resources/ingress-v1/):
"`/foo/bar` matches `/foo/bar/baz`, but does not match `/foo/barbaz`". So `/v1beta` does **not**
match the open `/v1`; it stays gated, and opening it means adding it to `omniroute_public_paths`
explicitly. This holds only while neither Ingress sets `use-regex` or `rewrite-target`: either one
forces regex locations onto **all** paths for the host and `/v1` would then swallow `/v1beta`.

`/v1` and `/api/v1` are both open because they are the same handler (the image rewrites one onto the
other). `/v1` is the canonical one the dashboard emits, so opening only `/api/v1` leaves the
dashboard handing out URLs that redirect to the login page.

Because the API prefixes are unauthenticated at the edge, the module forces
`extraConfig.REQUIRE_API_KEY: "true"` so OmniRoute requires an API key on every proxy call.
`REQUIRE_API_KEY` is resolved with a database override ahead of the environment value, so never
disable it from the dashboard while these prefixes are served open, or they become anonymous.

**Admin suffixes gated as defense in depth.** The open prefixes also carry management routes
(`/management`, `/agents`, `/accounts`, `/registered-keys`) that OpenAI-compatible clients never
call. `var.omniroute_gated_admin_suffixes` pulls them back onto the gated Ingress, so they need an
oauth2 session on top of the API key while model calls stay open. Dashboard browser calls still
pass, carrying the cookie. Set the variable to `[]` to disable.

The gated set is `locals.tf`'s alias prefixes crossed with these suffixes. **Every alias must be
covered**: the app aliases more prefixes onto `/api/v1` than the Ingress opens, and an alias the
Ingress does not open has no location of its own, so it falls to the open prefix and reaches the
handler ungated. `/v1/v1` is the live example. Both lists are app-version dependent; re-verify
against a running container on every image bump.

Both Ingresses share one host and one TLS secret, and only `omniroute-ui` carries
`cert-manager.io/cluster-issuer`. Annotating both would create competing Certificates for the same
secret.

**Residual public surface.** Only the paths in `omniroute_public_paths` are unauthenticated.
Anything else falls through to the gated Ingress. If you enable web-cookie providers (`gemini-web`,
`claude-web`) or external OAuth/webhook callbacks, those callback paths must be added to
`omniroute_public_paths` or the provider handshake fails behind the login redirect:

| Candidate path | When to add it |
|---|---|
| `/api/v1`, `/v1` | Always (both are defaults). The OpenAI-compatible API base paths, same handlers |
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
| `omniroute_domain` | string | `omniroute.chrislee.local` | Single host serving the API and the dashboard |
| `omniroute_ingress_class_name` | string | `nginx` | Ingress class for both Ingresses |
| `omniroute_ingress_enable_tls` | bool | `true` | Wired from the root `ingress_enable_tls` |
| `omniroute_public_paths` | list(string) | `["/api/v1", "/v1"]` | Paths routed to the open API Ingress. Omissions fall through to oauth2-proxy |
| `omniroute_gated_admin_suffixes` | list(string) | `["/management", "/agents", "/accounts", "/registered-keys"]` | Admin suffixes pulled back behind oauth2-proxy, applied to every API alias prefix (`/api/v1`, `/v1`, `/v1/v1`). `[]` disables |
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
curl -sS https://$DOMAIN/v1/models -H "Authorization: Bearer $API_KEY"

# Admin suffixes must stay gated on every alias. Anything but a 302 means the request reached the
# app and the gate was bypassed. Re-run after every image bump.
for p in /v1/management /api/v1/management /v1/v1/management; do
  code=$(curl -so /dev/null -w '%{http_code}' "https://$DOMAIN$p")
  [ "$code" = "302" ] || echo "GATE BYPASS: $p returned $code"
done
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
- **Heap cap and memory limit move together.** `OMNIROUTE_MEMORY_MB` is the V8 old-space ceiling and
  `resources.limits.memory` must clear it by several hundred MiB, both in
  `templates/omniroute-values.tftpl`. Undersizing the cap aborts the process with "Reached heap
  limit" and reports exit 0, so it looks like a clean shutdown. `OmniRouteMemoryNearHeapCeiling` in
  [monitoring](../monitoring/prometheus-rules/omniroute-rules.tftpl) is tuned to the gap between the
  two values, so retune it when either changes.
- **Restarts are full downtime.** One replica on a single-writer PVC with a `Recreate` strategy, so
  every restart or apply drops the gateway for roughly 30s. `OmniRouteContainerRestarted` and
  `OmniRouteDown` page on this; stock `KubePodCrashLooping` does not, because the pod recovers
  without entering `CrashLoopBackOff`.
