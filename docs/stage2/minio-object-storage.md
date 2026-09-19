# MinIO Object Storage Module

Terraform module for deploying [MinIO](https://min.io/) S3-compatible object storage to Kubernetes. Provides object storage for GitLab artifacts, container registry, backups, and other services requiring S3-compatible storage.

## Architecture

```mermaid
flowchart TB
    subgraph external [External Clients]
        GitLab[GitLab]
        Registry[Container Registry]
        Backup[Backup Jobs]
        User[Admin User]
    end

    subgraph k8s [Kubernetes Cluster]
        subgraph ingress [Edge Layer]
            Gateway[Istio Gateway<br/>console and S3 api hosts]
            OAuth[OAuth2 Proxy<br/>ext_authz provider]
        end

        subgraph operator_ns [Namespace: minio-operator]
            Operator[MinIO Operator]
        end

        subgraph tenant_ns [Namespace: minio-tenant]
            subgraph tenant [MinIO Tenant]
                API[S3 API :9000]
                Console[Console UI :9090]
            end

            subgraph storage [Persistent Storage]
                PVC0[(data0 PVC)]
                PVC1[(data1 PVC)]
                PVC2[(data2 PVC)]
                PVC3[(data3 PVC)]
            end

            Secret[Credentials Secret]
        end
    end

    User --> Gateway
    Gateway -->|ext_authz check, console only| OAuth
    Gateway -->|HTTPRoute| Console
    Gateway -->|HTTPRoute| API

    GitLab -->|S3 API| Gateway
    Registry -->|S3 API| Gateway
    Backup -->|S3 API| Gateway

    Operator -->|manages| tenant
    API --> PVC0
    API --> PVC1
    API --> PVC2
    API --> PVC3
    tenant --> Secret
```

## Request Flow

```mermaid
sequenceDiagram
    participant Client as GitLab/App
    participant Gateway as Istio Gateway
    participant MinIO as MinIO Tenant
    participant Storage as Longhorn PVC

    Client->>Gateway: PUT object, S3 API
    Gateway->>MinIO: Forward request, body streamed
    Note over MinIO: Authenticate with access key
    MinIO->>Storage: Write object data
    Storage-->>MinIO: Confirm write
    MinIO-->>Gateway: 200 OK
    Gateway-->>Client: Object stored
```

## Resources Created

- `kubernetes_namespace.minio_operator` - Operator namespace
- `kubernetes_namespace.minio_tenant` - Tenant namespace
- `kubernetes_secret.minio_tenant_env` - Root credentials
- `kubernetes_secret.minio_tenant_user` - User access credentials
- `helm_release.minio_operator` - MinIO Operator
- `helm_release.minio_tenant` - MinIO Tenant
- `kubectl_manifest.console_listener` - ListenerSet contributing the console HTTPS listener to the shared Gateway
- `kubectl_manifest.console_certificate` - DNS-01 Certificate for the console host, reusing the Secret name the Ingress used
- `kubectl_manifest.console_route` - HTTPRoute for the console host, carrying the header filters
- `kubectl_manifest.console_require_auth` - CUSTOM AuthorizationPolicy for the console host, in the Gateway namespace
- `kubectl_manifest.api_listener` - ListenerSet contributing the S3 api HTTPS listener to the shared Gateway
- `kubectl_manifest.api_certificate` - DNS-01 Certificate for the S3 api host, reusing the Secret name the Ingress used
- `kubectl_manifest.api_route` - HTTPRoute for the S3 api host, carrying the header filters and no auth policy

## Variables

| Name | Description | Default |
|------|-------------|---------|
| `minio_tenant_root_user` | Root username | `minio` |
| `minio_tenant_pools_servers` | Number of MinIO servers | `1` |
| `minio_tenant_pools_size` | Storage capacity per volume | `10Gi` |
| `minio_tenant_pools_storage_class_name` | Storage class for PVCs | `longhorn` |
| `minio_tenant_default_buckets` | List of buckets to create | (required) |
| `minio_tenant_user_access_key` | User access key | `minio-user` |
| `minio_tenant_ingress_api_host` | S3 API hostname. Served by the gateway with no AuthorizationPolicy, because callers authenticate with S3 SigV4 | `minio.chrislee.local` |
| `minio_tenant_ingress_console_host` | Console hostname | `minio-console.chrislee.local` |
| `istio_gateway_name` | Shared Istio Gateway both listeners are added to | `public` |
| `istio_gateway_namespace` | Namespace of that Gateway, and where the AuthorizationPolicy is created | `istio-ingress` |

## Default Buckets

The module creates these buckets for GitLab integration:

- `registry` - Container registry storage
- `git-lfs` - Git LFS objects
- `runner-cache` - CI runner cache
- `gitlab-uploads` - User uploads
- `gitlab-artifacts` - CI artifacts
- `gitlab-backups` - Automated backups
- `gitlab-packages` - Package registry
- `gitlab-mr-diffs` - Merge request diffs
- `gitlab-terraform-state` - Terraform state
- `gitlab-pages` - GitLab Pages
- `gitlab-registry-storage` - Registry metadata

## Usage

### Configure Storage Size

```bash
TF_VAR_minio_tenant_pools_size="50Gi"
```

### Access Console

Navigate to `https://minio-console.chrislee.local`. The console is served by the Istio gateway and gated by ext_authz. The S3 api host is served by the same gateway with no gate, because clients authenticate with AWS SigV4 against MinIO itself and a login redirect would break every S3 caller.

### Use S3 API

```bash
# Configure AWS CLI
aws configure set aws_access_key_id minio-user
aws configure set aws_secret_access_key <secret-from-terraform-output>

# List buckets
aws --endpoint-url https://minio.chrislee.local s3 ls

# Upload file
aws --endpoint-url https://minio.chrislee.local s3 cp file.txt s3://gitlab-backups/
```

## Helm Charts

| Component | Repository | Chart |
|-----------|------------|-------|
| Operator | <https://operator.min.io> | operator |
| Tenant | <https://operator.min.io> | tenant |

## Outputs

| Name | Description |
|------|-------------|
| `minio_tenant_user_secret_key` | User secret key for S3 access |

## Expanding Storage

To expand PVC storage when full:

```bash
kubectl edit -n minio-tenant pvc data0-minio-tenant-pool-0-0
kubectl edit -n minio-tenant pvc data1-minio-tenant-pool-0-0
kubectl edit -n minio-tenant pvc data2-minio-tenant-pool-0-0
kubectl edit -n minio-tenant pvc data3-minio-tenant-pool-0-0
```

## References

- [MinIO Documentation](https://min.io/docs/minio/kubernetes/upstream/)
- [MinIO Operator](https://github.com/minio/operator)
- [S3 API Reference](https://docs.aws.amazon.com/AmazonS3/latest/API/Welcome.html)
