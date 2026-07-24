# LiteLLM

Self-hosted [LiteLLM](https://docs.litellm.ai/docs/proxy/deploy) proxy: one OpenAI-compatible `/v1`
endpoint in front of many upstream providers, plus an admin console at `/ui`.

Disabled by default. Set `litellm_enable = true` (or `TF_VAR_litellm_enable`) to deploy.

## What this module creates

| Resource | Name | Notes |
|---|---|---|
| Namespace | `litellm` | |
| Secret | `litellm-masterkey` | Chart injects it as env `PROXY_MASTER_KEY` |
| Secret | `litellm-env` | `LITELLM_SALT_KEY` + provider API keys, mounted with `envFrom` |
| Secret | `litellm-db` | Postgres `username` / `password` |
| StatefulSet + Service | `litellm-postgres` | Upstream `postgres:*-alpine` on a Longhorn PVC |
| Helm release | `litellm` | Chart `litellm-helm`, from `oci://ghcr.io/berriai` |
| Ingress | `litellm-api` | Path `/`, SSE-safe, TLS + cert-manager annotation |
| Ingress | `litellm-ui` | `var.litellm_ui_paths`, behind oauth2-proxy |

## Design notes

**Module-owned Postgres, not the chart's.** The chart's `db.deployStandalone` path generates its own
`<release>-dbcredentials` Secret from plaintext Helm values and ignores `existingSecret`, which
would put the database password into the Helm release secret and into Terraform state. This module
uses `db.useExisting` and points the chart at `litellm-db`, so both the Deployment and the Prisma
migrations Job read the credentials via `secretKeyRef`. Bitnami's postgresql image is also 404 on
Docker Hub since the August 2025 catalog migration.

**Split ingress.** The chart's single Ingress serves `/v1` and `/ui` together. The console is
reachable with no credentials while the API enforces the virtual/master key — so the console HTML is
effectively public and only the API is protected. The chart Ingress is therefore disabled and the
module writes two: an oauth2-proxy-gated one for the console paths, and a clean one for everything
else.

`litellm_ui_paths` has to cover every path the console actually uses, because whatever it omits
falls through to the unauthenticated API Ingress. Beyond `/ui` and `/sso` that means
`/litellm-asset-prefix` (the console loads its JS and CSS from there, not from `/ui`),
`/fallback/login` (the login form itself, served unauthenticated) and `/login` (the credential POST
target). These paths track the upstream console, so recheck them when bumping the chart.

Both Ingresses share one host and one TLS secret, and only `litellm-api` carries
`cert-manager.io/cluster-issuer`. Annotating both would create competing Certificates for the same
secret.

**Residual public surface.** LiteLLM serves a fixed allow-list of unauthenticated routes under `/`.
`NO_DOCS: "True"` only removes the `/docs` UI — `/openapi.json` still returns the full schema and
`/redoc` still renders it. So the introspection routes (`/docs`, `/redoc`, `/openapi.json`,
`/routes`, `/config/yaml`, `/public`) are gated by `litellm_ui_paths` instead, and `NO_DOCS` is
defence in depth. `/config/yaml` returns the proxy config and `/public/*` the model, agent, mcp and
skill hubs, so both disclose which providers hold keys here; no OpenAI-SDK client requests either.

Still public by design, and deliberately not gated:

| Route | Why it stays open |
|-------|-------------------|
| `/` | Also the API catch-all prefix; gating it would break every client |
| `/health/liveliness`, `/health/liveness` | Probes and external monitoring. `/health/readiness` is not on the upstream allow-list and already requires auth |
| `/.well-known/*` | cert-manager's HTTP-01 solver answers under `/.well-known/acme-challenge` |
| `/test` | Upstream public-route allow-list; returns a static response, discloses nothing |

**No `model_list` in git.** `store_model_in_db: true` lets an admin add models live in `/ui`,
persisted in Postgres. The values template sets `model_list: null` explicitly — omitting the key
would let the chart's own example model coalesce into the rendered ConfigMap. To promote a model
into git, replace the null with a list and keep API keys as `os.environ/<KEY>` references.

**Adding a provider** needs no Terraform change: add the key to the
`TF_VAR_litellm_provider_secrets` JSON object and reference it from `proxy_config` as
`os.environ/<KEY>`.

## Variables

| Variable | Type | Default | Purpose |
|---|---|---|---|
| `litellm_enable` | bool | `false` | Module gate. Everything below is inert while false |
| `litellm_domain` | string | `litellm.chrislee.local` | Single host serving both `/v1` and `/ui` |
| `litellm_ingress_class_name` | string | `nginx` | Ingress class for both Ingresses |
| `litellm_ingress_enable_tls` | bool | `true` | Wired from the root `ingress_enable_tls` |
| `litellm_ui_paths` | list(string) | `["/ui", "/sso", "/litellm-asset-prefix", "/fallback/login", "/login", "/docs", "/redoc", "/openapi.json", "/routes", "/config/yaml", "/public"]` | Paths routed behind oauth2-proxy. Omissions fall through unauthenticated |
| `litellm_chart_version` | string | `1.89.2` | `litellm-helm` chart pin |
| `litellm_image_tag` | string | `1.89.2` | `ghcr.io/berriai/litellm-database` pin. Bump with the chart |
| `litellm_postgres_image_tag` | string | `18.4-alpine` | Must end in `-alpine`: the pod sets `fs_group = 70` |
| `litellm_replicas` | number | `1` | Proxy replicas, minimum 1 |
| `litellm_storage_class_name` | string | `longhorn` | Postgres volume storage class |
| `litellm_storage_size` | string | `10Gi` | Postgres volume size. See the resize caveat below |
| `litellm_master_key` | string, sensitive | `""` | Admin/API superuser key, must start with `sk-` |
| `litellm_salt_key` | string, sensitive | `""` | Encrypts DB-stored credentials, must start with `sk-`. Write once |
| `litellm_db_password` | string, sensitive | `""` | Postgres password, minimum 16 characters, restricted to `A-Z a-z 0-9 _ . ~ -` because it is interpolated into a `postgresql://` URI |
| `litellm_provider_secrets` | map(string), sensitive | `{}` | Provider API keys exported to the pod as env vars |
| `auth_oauth2_proxy_host` | string | `""` | oauth2-proxy host guarding the console |

The three string credentials (`litellm_master_key`, `litellm_salt_key`, `litellm_db_password`)
default to `""` so the module stays valid while disabled. Their `validation` blocks reject a
malformed non-empty value; `precondition` blocks in `secrets.tf` make them mandatory once
`litellm_enable = true`. `litellm_provider_secrets` carries neither layer and stays optional: a
proxy with no providers configured yet is a valid state.

## Secrets

Supplied through Bitwarden Secrets Manager as `TF_VAR_*`; see
[docs/bitwarden-secrets-setup.md](../../docs/bitwarden-secrets-setup.md).

| Variable | How to generate |
|---|---|
| `litellm_master_key` | `echo "sk-$(openssl rand -hex 24)"` |
| `litellm_salt_key` | `echo "sk-$(openssl rand -hex 24)"` |
| `litellm_db_password` | `openssl rand -hex 16` |
| `litellm_provider_secrets` | JSON object of provider keys |

> `litellm_salt_key` encrypts every provider credential stored in the database. **Write it once and
> never rotate it** — rotating makes all stored credentials permanently unreadable.

## Operations

```bash
kubectl -n litellm get pods,sts,pvc,ingress
kubectl -n litellm logs job/litellm-migrations   # "All migrations have been successfully applied."
                                                 # Job self-deletes 1h after finishing
                                                 # (migrationJob.ttlSecondsAfterFinished)

curl -sS https://$DOMAIN/health/liveliness       # 200, no auth
curl -sS https://$DOMAIN/v1/models -H "Authorization: Bearer $MASTER_KEY"
```

`/v1/models` returns an empty list until models are added through `/ui`.

## Caveats

- **The database holds the only copy of model configuration.** With `model_list` empty in git,
  models added through `/ui` exist only in Postgres. Setting `litellm_enable = false` deletes the
  Namespace, and that is what reaps the PVC — deleting a StatefulSet on its own leaves PVCs behind,
  since the default volume-claim retention policy is `Retain`. Promote anything important into
  `proxy_config`.
- **`helm rollback` does not re-run migrations.** The migration Job is a `pre-install,pre-upgrade`
  hook, and a rollback fires `pre-rollback` instead, so the old image would meet the new schema.
  Prisma migrations are forward-only: recover by rolling `litellm_chart_version` and
  `litellm_image_tag` forward, never back. Terraform never rolls back on its own, so this only
  applies to a manual `helm rollback`.
- **Growing `litellm_storage_size` does not resize the volume.** Changing it replaces the
  StatefulSet, but the existing PVC survives replacement and the controller only creates PVCs that
  are missing, so the new size is never applied. Expand the volume directly instead, then update
  the variable to match so the two do not diverge:

  ```bash
  kubectl -n litellm patch pvc data-litellm-postgres-0 \
    -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
  ```

  Longhorn supports online expansion, so no downtime is needed. Shrinking is not possible.
- **Rotating `litellm_db_password` breaks the deployment.** The postgres image only reads
  `POSTGRES_PASSWORD` when the data directory is empty, so a new value updates the Secret and the
  clients but not the database role, and every connection starts failing authentication. Change the
  role first, then the variable:

  ```bash
  kubectl -n litellm exec -it litellm-postgres-0 -- \
    psql -U litellm -d litellm -c "ALTER USER litellm WITH PASSWORD '<new>';"
  ```
- **TLS on a `.local` domain never issues.** `letsencrypt-prod` cannot complete an HTTP-01
  challenge for `litellm.chrislee.local`. Certificates only issue once a real public domain is set.
  This is the repo-wide pattern, not specific to this module.
- **Chart and image versions move together.** Bump `litellm_chart_version` and `litellm_image_tag`
  as a pair.
