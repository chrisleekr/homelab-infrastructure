# Monitoring Module

Terraform module for deploying the [Prometheus Stack](https://prometheus.io/) (Prometheus, Grafana, AlertManager) and [ElastAlert2](https://elastalert2.readthedocs.io/) to Kubernetes. Provides comprehensive metrics collection, visualization, and alerting for the entire cluster.

## Architecture

```mermaid
flowchart TB
    subgraph external [External]
        User[User Browser]
        Slack[Slack]
    end

    subgraph k8s [Kubernetes Cluster]
        subgraph ingress [Ingress Layer]
            Nginx[NGINX Ingress]
            OAuth[OAuth2 Proxy]
        end

        subgraph ns [Namespace: monitoring]
            subgraph prom [Prometheus Stack]
                Prometheus[Prometheus]
                Grafana[Grafana]
                AlertManager[AlertManager]
            end

            subgraph elastic [ElastAlert2]
                ElastAlert[ElastAlert2]
            end

            subgraph rules [PrometheusRules]
                LonghornRules[Longhorn Rules]
                PostgresRules[PostgreSQL Rules]
                RedisRules[Redis Rules]
            end

            PromPVC[(Prometheus PVC)]
            GrafanaPVC[(Grafana PVC)]
        end

        subgraph targets [Scrape Targets]
            NodeExporter[Node Exporter]
            KubeStateMetrics[kube-state-metrics]
            MinIO[MinIO Metrics]
            ServiceMonitors[ServiceMonitors]
        end

        subgraph logging [Logging Module]
            Elasticsearch[(Elasticsearch)]
        end
    end

    User --> Nginx
    Nginx --> OAuth
    OAuth --> Grafana
    OAuth --> Prometheus
    OAuth --> AlertManager

    Prometheus -->|scrape| targets
    Prometheus --> PromPVC
    Prometheus -->|evaluate| rules
    rules -->|fire alerts| AlertManager
    AlertManager -->|notify| Slack

    ElastAlert -->|query| Elasticsearch
    ElastAlert -->|alert| Slack

    Grafana --> GrafanaPVC
    Grafana -->|query| Prometheus
```

## Alert Flow

```mermaid
sequenceDiagram
    participant Prometheus
    participant Rules as PrometheusRules
    participant AM as AlertManager
    participant Slack

    Prometheus->>Prometheus: Scrape metrics
    Prometheus->>Rules: Evaluate rules
    Rules-->>Prometheus: Alert firing
    Prometheus->>AM: Send alert
    AM->>AM: Group/Deduplicate
    AM->>Slack: Send notification
```

## Resources Created

- `kubernetes_namespace.monitoring_namespace` - Dedicated namespace
- `kubernetes_secret.frontend_basic_auth` - Basic auth for UIs
- `random_password.grafana_admin_password` - Grafana admin password
- `kubectl_manifest.prometheus_rules` - Custom PrometheusRules
- `helm_release.prometheus_operator` - kube-prometheus-stack
- `kubernetes_secret.elastalert2_credentials` - ElastAlert2 credentials
- `kubernetes_secret.elastalert2_config` - ElastAlert2 configuration
- `helm_release.elastalert2` - ElastAlert2 chart

## Variables

### Prometheus Stack

| Name | Description | Default |
|------|-------------|---------|
| `nginx_frontend_basic_auth_base64` | Basic auth credentials | (required, sensitive) |
| `prometheus_alertmanager_domain` | AlertManager hostname | `alertmanager.chrislee.local` |
| `prometheus_grafana_domain` | Grafana hostname | `grafana.chrislee.local` |
| `prometheus_grafana_storage_class` | Grafana storage class | `longhorn` |
| `prometheus_ingress_class_name` | Ingress class | `nginx` |
| `prometheus_ingress_enable_tls` | Enable TLS | `true` |
| `prometheus_prometheus_domain` | Prometheus hostname | `prometheus.chrislee.local` |
| `prometheus_persistence_storage_class_name` | Storage class | `longhorn` |
| `prometheus_persistence_size` | Prometheus storage size | `10Gi` |
| `prometheus_alertmanager_slack_channel` | Slack channel for alerts | (required) |
| `prometheus_alertmanager_slack_credentials` | Slack webhook URL | (required, sensitive) |
| `prometheus_minio_job_bearer_token` | MinIO metrics token | (required, sensitive) |

### ElastAlert2

| Name | Description | Default |
|------|-------------|---------|
| `elastalert2_elasticsearch_enabled` | Enable ElastAlert2 | `true` |
| `elastalert2_elasticsearch_host` | Elasticsearch host | (from logging module) |
| `elastalert2_elasticsearch_port` | Elasticsearch port | (from logging module) |
| `elastalert2_elasticsearch_username` | Elasticsearch username | (from logging module) |
| `elastalert2_elasticsearch_password` | Elasticsearch password | (from logging module, sensitive) |

## Usage

### Configure Slack Alerts

```bash
TF_VAR_prometheus_alertmanager_slack_channel="#alerts"
TF_VAR_prometheus_alertmanager_slack_credentials="https://hooks.slack.com/services/xxx"
```

### Access Dashboards

| Service | URL | Authentication |
|---------|-----|----------------|
| Grafana | <https://grafana.chrislee.local> | OAuth2 + Admin password |
| Prometheus | <https://prometheus.chrislee.local> | OAuth2 |
| AlertManager | <https://alertmanager.chrislee.local> | OAuth2 |

### Get Grafana Admin Password

```bash
kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

## Helm Charts

| Component | Repository | Chart |
|-----------|------------|-------|
| Prometheus Stack | prometheus-community | kube-prometheus-stack |
| ElastAlert2 | jertel | elastalert2 |

## PrometheusRules

Custom alerting rules are defined in `prometheus-rules/`:

| File | Purpose |
|------|---------|
| `longhorn-rules.tftpl` | Longhorn storage alerts |
| `postgres-rules.tftpl` | PostgreSQL database alerts |
| `redis-rules.tftpl` | Redis cache alerts |

## Pre-configured Dashboards

Grafana includes dashboards for:

- Kubernetes cluster overview
- Node metrics
- Pod resources
- Persistent volumes
- NGINX Ingress
- CoreDNS
- GitLab (if enabled)

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [AlertManager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [ElastAlert2 Documentation](https://elastalert2.readthedocs.io/)
