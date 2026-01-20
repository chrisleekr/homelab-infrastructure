# Stakater Reloader Module

Terraform module for deploying [Stakater Reloader](https://github.com/stakater/Reloader) to Kubernetes. Automatically triggers rolling upgrades on Deployments, StatefulSets, and DaemonSets when their referenced ConfigMaps or Secrets are updated.

## Architecture

```mermaid
flowchart TB
    subgraph k8s [Kubernetes Cluster]
        subgraph ns [Namespace: reloader]
            Reloader[Reloader Controller]
        end

        subgraph watched [Watched Resources]
            CM[ConfigMaps]
            Secret[Secrets]
        end

        subgraph workloads [Workloads]
            Deploy[Deployments]
            STS[StatefulSets]
            DS[DaemonSets]
        end
    end

    Reloader -->|watches| CM
    Reloader -->|watches| Secret
    CM -.->|triggers rollout| Deploy
    Secret -.->|triggers rollout| STS
    CM -.->|triggers rollout| DS
```

## How It Works

```mermaid
sequenceDiagram
    participant User
    participant K8s as Kubernetes API
    participant Reloader
    participant Workload as Deployment/StatefulSet

    User->>K8s: Update ConfigMap/Secret
    K8s->>Reloader: Watch event received
    Note over Reloader: Detect annotation on workload
    Reloader->>K8s: Trigger rolling restart
    K8s->>Workload: New pods with updated config
```

## Resources Created

- `kubernetes_namespace.reloader_namespace` - Dedicated namespace
- `helm_release.reloader` - Reloader Helm chart deployment

## Variables

This module has no input variables. It uses sensible defaults.

## Usage

The module is automatically deployed as part of the infrastructure. To use Reloader with your workloads, add one of these annotations:

**Watch specific ConfigMap:**

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

**Watch specific resources:**

```yaml
metadata:
  annotations:
    configmap.reloader.stakater.com/reload: "my-configmap"
    secret.reloader.stakater.com/reload: "my-secret"
```

## Helm Chart

| Property | Value |
|----------|-------|
| Repository | <https://stakater.github.io/stakater-charts> |
| Chart | reloader |

## References

- [Stakater Reloader GitHub](https://github.com/stakater/Reloader)
- [Helm Chart Documentation](https://github.com/stakater/Reloader/tree/master/deployments/kubernetes/chart/reloader)
