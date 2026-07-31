# Verify the install

Run these from inside the tooling container: `task docker:exec`.

## Cluster

```bash
kubectl get nodes -o wide
```

Every node `Ready`, every node on the same version, and worker architectures as expected.

```bash
kubectl get pods -A --field-selector=status.phase!=Running
```

Should be empty, or only `Completed` jobs.

## Networking

```bash
cilium status                          # kubeadm path only
kubectl get svc -A --field-selector spec.type=LoadBalancer
```

Every `LoadBalancer` service must have an `EXTERNAL-IP`. A `<pending>` here means MetalLB is missing
or has no free address in its pool. See [`localhost_post_setup`](../stage1/roles/localhost-post-setup.md).
Nothing in the platform is reachable until this is resolved.

## Storage

```bash
kubectl get storageclass
kubectl get pvc -A
```

Longhorn should be the default StorageClass, and no PVC should be stuck `Pending`.

## Metrics

```bash
kubectl top nodes
```

An error here means metrics-server did not install. Horizontal pod autoscaling and the Grafana node
dashboards both depend on it.

## Certificates

```bash
kubectl get certificate -A
```

Every certificate `READY=True`. A stuck certificate is usually DNS: the HTTP-01 challenge needs the
name to resolve to your ingress from outside.

```bash
kubectl describe certificaterequest -A | tail -40
```

## Web UIs

Each is behind OAuth2 Proxy and Auth0, at `service.domain.local`:

| Service | Module |
|---|---|
| Grafana | [monitoring](../stage2/monitoring.md) |
| ArgoCD | [argocd](../stage2/argocd.md) |
| GitLab | [gitlab-platform](../stage2/gitlab-platform.md) |
| Longhorn | [longhorn-storage](../stage2/longhorn-storage.md) |
| MinIO | [minio-object-storage](../stage2/minio-object-storage.md) |
| Kibana | [logging](../stage2/logging.md) |
| Kubecost | [monitoring-kubecost](../stage2/monitoring-kubecost.md) |

A TLS warning means the certificate is not issued yet. A 500 from the proxy usually means the Auth0
callback URL does not match the ingress hostname.

## The version convergence contract

Play 5 of the playbook already asserted this, but to check it yourself:

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}'
```

Every kubelet on the version pinned in `stage1/inventories/inventory.yml`. See
[Version pins](../reference/versions.md).

## If something is wrong

- [Troubleshooting](../operations/troubleshooting.md)
- [Stage 1 architecture](../stage1/architecture.md) for what should be running on a node
- [Module dependency graph](../stage2/dependency-graph.md) for what should have deployed before what
