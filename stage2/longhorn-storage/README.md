# Longhorn Storage Module

Terraform module for deploying [Longhorn](https://longhorn.io/) distributed block storage to Kubernetes. Provides persistent volumes with replication, snapshots, and backups for stateful workloads.

## Architecture

```mermaid
flowchart TB
    subgraph k8s [Kubernetes Cluster]
        subgraph ns [Namespace: longhorn-system]
            Manager[Longhorn Manager]
            UI[Longhorn UI]
            Driver[CSI Driver]
        end

        subgraph workloads [Workloads]
            GitLab[(GitLab PVC)]
            Prometheus[(Prometheus PVC)]
            MinIO[(MinIO PVCs)]
        end

        subgraph node [Node Storage]
            Disk1["Data Path: /var/lib/longhorn"]
            Replica1[Volume Replicas]
        end

        subgraph ingress [Ingress Layer]
            Nginx[NGINX Ingress]
            OAuth[OAuth2 Proxy]
        end
    end

    User[User Browser] --> Nginx
    Nginx --> OAuth
    OAuth --> UI

    Manager --> Driver
    Driver --> GitLab
    Driver --> Prometheus
    Driver --> MinIO
    Manager --> Replica1
    Replica1 --> Disk1
```

## Volume Provisioning Flow

```mermaid
sequenceDiagram
    participant App as Application
    participant K8s as Kubernetes API
    participant CSI as Longhorn CSI
    participant Manager as Longhorn Manager
    participant Node as Node Storage

    App->>K8s: Create PVC (storageClass: longhorn)
    K8s->>CSI: Provision volume
    CSI->>Manager: Create volume request
    Manager->>Node: Allocate storage on disk
    Manager->>Manager: Create replica(s)
    Manager-->>CSI: Volume ready
    CSI-->>K8s: PV created and bound
    K8s-->>App: PVC bound, ready to use
```

## Resources Created

- `kubernetes_namespace.longhorn` - Dedicated namespace (longhorn-system)
- `kubernetes_secret.frontend_basic_auth` - Basic auth for UI
- `helm_release.longhorn` - Longhorn Helm chart
- `null_resource.remove_default` - Removes default StorageClass from local-path

## Variables

| Name | Description | Default |
|------|-------------|---------|
| `nginx_frontend_basic_auth_base64` | Base64 encoded basic auth | (required, sensitive) |
| `longhorn_default_settings_default_data_path` | Data storage path on nodes | `/var/lib/longhorn` |
| `longhorn_ingress_class_name` | Ingress class for UI | (required) |
| `longhorn_ingress_host` | Hostname for UI access | (required) |
| `longhorn_ingress_enable_tls` | Enable TLS for UI | `true` |
| `auth_oauth2_proxy_host` | OAuth2 proxy for authentication | `auth.chrislee.local` |

## Usage

### Configure Storage Path

Set custom data path if needed:

```bash
TF_VAR_longhorn_default_settings_default_data_path="/mnt/storage/longhorn"
```

### Configure UI Access

```bash
TF_VAR_longhorn_ingress_host="longhorn.chrislee.local"
```

### Access Dashboard

Navigate to `https://longhorn.chrislee.local` (OAuth2 protected).

## Helm Chart

| Property | Value |
|----------|-------|
| Repository | <https://charts.longhorn.io> |
| Chart | longhorn |

## StorageClass

After deployment, `longhorn` becomes the default StorageClass:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
```

## Features

| Feature | Description |
|---------|-------------|
| Replication | Configurable replica count for data redundancy |
| Snapshots | Point-in-time volume snapshots |
| Backups | Backup to S3-compatible storage (MinIO) |
| Expansion | Online volume expansion |
| Encryption | Volume encryption at rest |
| DR | Disaster recovery with cross-cluster replication |

## References

- [Longhorn Documentation](https://longhorn.io/docs/)
- [Longhorn Helm Chart](https://github.com/longhorn/charts)
- [Best Practices](https://longhorn.io/docs/latest/best-practices/)
