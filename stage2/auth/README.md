# OAuth2 Proxy Authentication Module

Terraform module for deploying [OAuth2 Proxy](https://oauth2-proxy.github.io/oauth2-proxy/) with Auth0 integration to Kubernetes. Provides centralized authentication for all protected services using OIDC.

## Architecture

```mermaid
flowchart TB
    subgraph external [External]
        User[User Browser]
        Auth0[Auth0 IdP]
    end

    subgraph k8s [Kubernetes Cluster]
        subgraph ingress [Ingress Layer]
            Nginx[NGINX Ingress]
        end

        subgraph ns [Namespace: auth]
            OAuth2[OAuth2 Proxy]
            Secret[Cookie/Client Secrets]
        end

        subgraph protected [Protected Services]
            Grafana[Grafana]
            Longhorn[Longhorn UI]
            Kibana[Kibana]
            ArgoCD[ArgoCD]
            MinIO[MinIO Console]
        end
    end

    User -->|1. Access protected service| Nginx
    Nginx -->|2. auth-url check| OAuth2
    OAuth2 -->|3. Redirect if unauthenticated| Auth0
    Auth0 -->|4. User authenticates| Auth0
    Auth0 -->|5. Callback with token| OAuth2
    OAuth2 -->|6. Set cookie, allow access| Nginx
    Nginx -->|7. Forward to service| protected
```

## Authentication Flow

```mermaid
sequenceDiagram
    participant User
    participant Nginx as NGINX Ingress
    participant OAuth2 as OAuth2 Proxy
    participant Auth0
    participant Service as Protected Service

    User->>Nginx: GET /dashboard
    Nginx->>OAuth2: GET /oauth2/auth
    OAuth2-->>Nginx: 401 Unauthorized
    Nginx-->>User: 302 Redirect to /oauth2/start

    User->>OAuth2: GET /oauth2/start
    OAuth2-->>User: 302 Redirect to Auth0

    User->>Auth0: Login page
    Auth0-->>User: 302 Callback with code

    User->>OAuth2: GET /oauth2/callback?code=xxx
    OAuth2->>Auth0: Exchange code for token
    Auth0-->>OAuth2: Access token + ID token
    OAuth2-->>User: Set cookie, 302 to original URL

    User->>Nginx: GET /dashboard (with cookie)
    Nginx->>OAuth2: GET /oauth2/auth (with cookie)
    OAuth2-->>Nginx: 200 OK + headers
    Nginx->>Service: Forward request
    Service-->>User: Dashboard content
```

## Resources Created

- `kubernetes_namespace.auth_namespace` - Dedicated namespace
- `random_password.oauth2_proxy_cookie_secret` - Cookie encryption secret
- `kubernetes_secret.oauth2_proxy_cookie_secret` - Credentials secret
- `helm_release.oauth2_proxy` - OAuth2 Proxy Helm chart

## Variables

| Name | Description | Default |
|------|-------------|---------|
| `prometheus_namespace` | Namespace for ServiceMonitor | `monitoring` |
| `auth_ingress_class_name` | Ingress class | `nginx` |
| `auth_ingress_enable_tls` | Enable TLS | `true` |
| `auth_oauth2_proxy_host` | Proxy hostname | `auth.chrislee.local` |
| `auth_oauth2_proxy_cookie_domains` | Cookie domains (JSON array) | `[".chrislee.local"]` |
| `auth_oauth2_proxy_whitelist_domains` | Allowed redirect domains | `["*.chrislee.local"]` |
| `auth_auth0_domain` | Auth0 tenant domain | `chrislee.auth0.com` |
| `auth_auth0_client_id` | Auth0 application client ID | `""` |
| `auth_auth0_client_secret` | Auth0 application client secret | (required, sensitive) |
| `auth_host_alias_ip` | Host alias IP for internal resolution | `""` |
| `auth_host_alias_hostnames` | Host alias hostnames | `""` |

## Usage

### 1. Configure Auth0 Application

1. Create a Regular Web Application in Auth0
2. Set Allowed Callback URLs: `https://auth.chrislee.local/oauth2/callback`
3. Set Allowed Logout URLs: `https://auth.chrislee.local`
4. Copy Client ID and Client Secret

### 2. Configure Variables

```bash
TF_VAR_auth_auth0_domain="your-tenant.auth0.com"
TF_VAR_auth_auth0_client_id="your-client-id"
TF_VAR_auth_auth0_client_secret="your-client-secret"
TF_VAR_auth_oauth2_proxy_host="auth.chrislee.local"
TF_VAR_auth_oauth2_proxy_cookie_domains='[".chrislee.local"]'
```

### 3. Protect a Service

Add these annotations to any Ingress:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/auth-url: "https://auth.chrislee.local/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://auth.chrislee.local/oauth2/start?rd=$scheme://$host$escaped_request_uri"
    nginx.ingress.kubernetes.io/auth-response-headers: "X-Auth-Request-User,X-Auth-Request-Email,X-Auth-Request-Access-Token"
```

## Helm Chart

| Property | Value |
|----------|-------|
| Repository | <https://oauth2-proxy.github.io/manifests> |
| Chart | oauth2-proxy |

## Protected Services

The following services use OAuth2 Proxy for authentication:

| Service | Ingress Host |
|---------|--------------|
| Grafana | grafana.chrislee.local |
| Longhorn | longhorn.chrislee.local |
| Kibana | kibana.chrislee.local |
| ArgoCD | argocd.chrislee.local |
| MinIO Console | minio-console.chrislee.local |
| Kubecost | cost.chrislee.local |
| LLM Gateway | llm.chrislee.local |

## References

- [OAuth2 Proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Auth0 Integration](https://oauth2-proxy.github.io/oauth2-proxy/configuration/providers/auth0)
- [NGINX Ingress External Auth](https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/)
