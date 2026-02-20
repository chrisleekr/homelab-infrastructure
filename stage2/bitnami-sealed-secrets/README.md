# Sealed Secrets Module

Terraform module for deploying [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) controller to Kubernetes. Enables GitOps-native secret management by encrypting secrets client-side and decrypting them in-cluster.

## Architecture

```mermaid
flowchart TB
    subgraph dev [Developer Machine]
        kubeseal[kubeseal CLI]
        pubkey[Controller Public Key]
    end

    subgraph git [Git Repository]
        SealedYAML["SealedSecret YAML<br/>(encrypted, safe to commit)"]
    end

    subgraph k8s [Kubernetes Cluster]
        subgraph ns [Namespace: sealed-secrets]
            Controller[Sealed Secrets Controller]
            PrivKey[Sealing Key Pair]
        end

        subgraph app_ns [Application Namespace]
            K8sSecret[Kubernetes Secret]
        end
    end

    kubeseal -->|encrypts with| pubkey
    kubeseal --> SealedYAML
    SealedYAML -->|ArgoCD syncs| Controller
    Controller -->|decrypts with| PrivKey
    Controller -->|creates| K8sSecret
    pubkey -.->|fetched from| Controller
```

## How It Works

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant KS as kubeseal CLI
    participant Git as Git Repo
    participant Argo as ArgoCD
    participant SC as Sealed Secrets Controller
    participant K8s as Kubernetes API

    Dev->>KS: kubeseal --format yaml < secret.yaml
    KS->>SC: Fetch public key
    KS->>Dev: SealedSecret YAML (encrypted)
    Dev->>Git: git commit + push
    Argo->>Git: Detect change (poll/webhook)
    Argo->>K8s: Apply SealedSecret CRD
    SC->>K8s: Watch SealedSecret events
    SC->>K8s: Decrypt and create Secret
```

## Resources Created

- `kubernetes_namespace_v1.sealed_secrets_namespace` — Dedicated namespace
- `helm_release.sealed_secrets` — Sealed Secrets Helm chart

## Variables

| Name | Description | Default |
|------|-------------|---------|
| `sealed_secrets_key_renewal_period` | Key renewal period | `720h` (30 days) |

## Usage

### Seal a new secret

```bash
# Create a regular secret YAML, then encrypt it
kubectl create secret generic my-secret \
  --namespace=my-app \
  --from-literal=API_KEY=supersecret \
  --dry-run=client -o yaml | \
  kubeseal \
    --controller-namespace sealed-secrets \
    --controller-name sealed-secrets-controller \
    --format yaml > my-sealed-secret.yaml
```

### Seal an existing secret from the cluster

```bash
kubectl get secret my-secret -n my-app -o yaml | \
  kubeseal \
    --controller-namespace sealed-secrets \
    --controller-name sealed-secrets-controller \
    --format yaml > my-sealed-secret.yaml
```

### Backup the sealing key (important!)

```bash
kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml
```

## Helm Chart

| Property | Value |
|----------|-------|
| Repository | <https://bitnami-labs.github.io/sealed-secrets> |
| Chart | sealed-secrets |
| Version | 2.18.1 |
| App Version | 0.35.0 |

## References

- [Sealed Secrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [ArgoCD Secret Management Best Practice](https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/)
- [Helm Chart Values](https://github.com/bitnami-labs/sealed-secrets/blob/main/helm/sealed-secrets/values.yaml)
