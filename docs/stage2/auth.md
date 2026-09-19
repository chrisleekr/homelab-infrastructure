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
            Gateway[Istio Gateway<br/>ext_authz to oauth2-proxy]
        end

        subgraph ns [Namespace: auth]
            OAuth2[OAuth2 Proxy]
            Secret[Cookie/Client Secrets]
        end

        subgraph protected [Protected Services]
            Grafana[Grafana]
            Longhorn[Longhorn UI]
            Kibana[Kibana]
            MinIO[MinIO Console]
        end
    end

    User -->|1. Access protected service| Gateway
    Gateway -->|2. ext_authz check| OAuth2
    OAuth2 -->|3. Redirect if unauthenticated| Auth0
    Auth0 -->|4. User authenticates| Auth0
    Auth0 -->|5. Callback with token| OAuth2
    OAuth2 -->|6. Set cookie, allow access| Gateway
    Gateway -->|7. Forward to service| protected
```

## Authentication Flow

```mermaid
sequenceDiagram
    participant User
    participant Gateway as Istio Gateway
    participant OAuth2 as OAuth2 Proxy
    participant Auth0
    participant Service as Protected Service

    User->>Gateway: GET /dashboard
    Gateway->>OAuth2: ext_authz check, original path
    OAuth2-->>Gateway: 401 Unauthorized
    Gateway-->>User: 302 Redirect to /oauth2/start

    User->>OAuth2: GET /oauth2/start
    OAuth2-->>User: 302 Redirect to Auth0

    User->>Auth0: Login page
    Auth0-->>User: 302 Callback with code

    User->>OAuth2: GET /oauth2/callback?code=xxx
    OAuth2->>Auth0: Exchange code for token
    Auth0-->>OAuth2: Access token + ID token
    OAuth2-->>User: Set cookie, 302 to original URL

    User->>Gateway: GET /dashboard with cookie
    Gateway->>OAuth2: ext_authz check with cookie
    OAuth2-->>Gateway: 200 OK + headers
    Gateway->>Service: Forward request
    Service-->>User: Dashboard content
```

## Resources Created

- `kubernetes_namespace.auth_namespace` - Dedicated namespace
- `random_password.oauth2_proxy_cookie_secret` - Cookie encryption secret
- `kubernetes_secret.oauth2_proxy_cookie_secret` - Credentials secret
- `helm_release.oauth2_proxy` - OAuth2 Proxy Helm chart
- `kubectl_manifest.listener` - ListenerSet contributing this host's HTTPS listener to the shared Gateway
- `kubectl_manifest.certificate` - DNS-01 Certificate, reusing the Secret name the Ingress used
- `kubectl_manifest.route` - HTTPRoute to `oauth2-proxy:80`, carrying the header filters

This host has no `AuthorizationPolicy` and must never gain one. oauth2-proxy is the ext_authz provider every gated host calls, so gating it would make the authenticator depend on itself.

## Variables

| Name | Description | Default |
|------|-------------|---------|
| `prometheus_namespace` | Namespace for ServiceMonitor | `monitoring` |
| `auth_oauth2_proxy_host` | Proxy hostname | `auth.chrislee.local` |
| `auth_oauth2_proxy_cookie_domains` | Cookie domains (JSON array) | `[".chrislee.local"]` |
| `auth_oauth2_proxy_whitelist_domains` | Allowed redirect domains | `["*.chrislee.local"]` |
| `auth_auth0_domain` | Auth0 tenant domain | `chrislee.auth0.com` |
| `auth_auth0_client_id` | Auth0 application client ID | `""` |
| `auth_auth0_client_secret` | Auth0 application client secret | (required, sensitive) |
| `istio_gateway_name` | Shared Istio Gateway the listener is added to | `public` |
| `istio_gateway_namespace` | Namespace of that Gateway, named by the ListenerSet `parentRef` | `istio-ingress` |

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

Declare a CUSTOM `AuthorizationPolicy` naming the shared Gateway. `action: CUSTOM` hands the decision to the `oauth2-proxy` ext_authz provider declared in mesh config, so the gate is enforced at the gateway rather than by the backend:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: myapp-require-auth
  # Beside the Gateway it targets, not beside the workload: Istio requires a policy to sit in the
  # namespace of the resource its targetRefs names.
  namespace: istio-ingress
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: public
  action: CUSTOM
  provider:
    name: oauth2-proxy
  rules:
    - to:
        - operation:
            # Both forms: the authority carries the port when a client sends one.
            hosts:
              - myapp.example.com
              - "myapp.example.com:*"
```

Add `paths` to gate only part of a host, or `notPaths` to gate everything except a named set. `stage2/omniroute-gateway/httproute.tf` and `stage2/litellm/httproute.tf` are the two worked examples, gating by exclusion and by inclusion respectively.

## Helm Chart

| Property | Value |
|----------|-------|
| Repository | <https://oauth2-proxy.github.io/manifests> |
| Chart | oauth2-proxy |

## References

- [OAuth2 Proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Auth0 Integration](https://oauth2-proxy.github.io/oauth2-proxy/configuration/providers/auth0)
- [Istio external authorization](https://istio.io/latest/docs/tasks/security/authorization/authz-custom/)
