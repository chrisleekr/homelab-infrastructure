# AGENTS.md: AI Collaboration Guide

This document provides essential guidelines for AI models interacting with this homelab infrastructure project. Following these standards ensures consistency, maintains code quality, and helps AI agents understand the project's architecture and deployment workflows.

## Project Overview

**Homelab Infrastructure** - A comprehensive two-stage infrastructure-as-code solution for provisioning single-node Kubernetes clusters with enterprise-grade applications. Uses Ansible for server setup and Kubernetes cluster bootstrap, followed by Terraform for deploying a complete application stack including GitLab, monitoring, storage, VPN, and CI/CD tools.

**Core Architecture:**

- **Stage 1 (Ansible)**: Server hardening, Kubernetes cluster provisioning (kubeadm/k3s/minikube)
- **Stage 2 (Terraform)**: Application deployment and infrastructure services
- **Containerized Tooling**: Docker image with kubectl, helm, terraform, ansible, kubent

**Supported Platforms:**

- **Target**: Ubuntu AMD64 servers (GitLab limitation)
- **Kubernetes Options**: kubeadm (recommended), k3s (alternative), minikube (experimental)
- **Infrastructure**: Single-node clusters optimized for homelab environments

## Project Structure

```text
homelab-infrastructure/
├── stage1/                   # Ansible playbooks and roles
│   ├── ansible.cfg           # Ansible configuration
│   ├── site.yml              # Main playbook orchestration
│   ├── inventories/          # Inventory configurations
│   │   └── inventory.yml     # Host and variable definitions
│   ├── roles/                # Ansible roles for infrastructure setup
│   │   ├── host_setup/       # Server hardening (fail2ban, ufw, package management)
│   │   ├── kubeadm_*/        # kubeadm cluster setup roles
│   │   ├── k3s_*/            # k3s cluster setup roles
│   │   ├── minikube_*/       # minikube cluster setup roles
│   │   └── localhost_post_setup/ # Local post-deployment tasks
│   └── requirements*.txt     # Python and Ansible dependencies
├── stage2/                   # Terraform modules and configurations
│   ├── main.tf               # Root module orchestration
│   ├── variables.tf          # Input variables definition
│   ├── providers.tf          # Provider configurations
│   ├── backend.tf            # Terraform Cloud backend
│   ├── kubernetes/           # Core Kubernetes configuration (CoreDNS, CRDs)
│   ├── nginx/                # Ingress controller
│   ├── cert-manager-letsencrypt/ # TLS certificate management
│   ├── longhorn-storage/     # Distributed block storage
│   │   ├── longhorn.tf
│   │   ├── provider.tf
│   │   ├── variables.tf
│   │   └── templates/
│   │       └── longhorn-values.tftpl
│   ├── minio-object-storage/ # S3-compatible object storage
│   ├── gitlab-platform/      # GitLab CI/CD platform
│   ├── monitoring/           # Prometheus, Grafana, AlertManager stack
│   ├── logging/              # Elasticsearch, Kibana, Filebeat (ECK)
│   ├── auth/                 # OAuth2 proxy authentication
│   ├── argocd/               # GitOps continuous deployment
│   ├── kubecost/             # Kubernetes cost monitoring
│   └── vpn/                  # Tailscale and WireGuard VPN
├── scripts/                  # Helper scripts
│   ├── docker-build.sh       # Build container image
│   ├── docker-run.sh         # Run container with proper mounts
│   └── repo-setup.sh         # Repository initialization
├── container/                # Container customization files
├── Dockerfile                # Multi-stage Alpine container definition
└── package.json              # npm scripts for workflow automation
```

## Build & Commands

**Container Management:**

- **Setup environment**: `npm run repo:setup` (install dependencies)
- **Build container**: `npm run docker:build` (create Alpine image with tools)
- **Run container**: `npm run docker:run` (start with volume mounts)
- **Access container**: `npm run docker:exec` (interactive bash session)

**Stage 1 (Ansible) - Kubernetes Cluster Setup:**

```bash
# Access container and navigate to stage1
npm run docker:exec
cd stage1

# Verify connectivity to target server
ansible all -i "inventories/inventory.yml" -m ping

# Deploy complete server setup and Kubernetes cluster
ansible-playbook --ask-become-pass -i "inventories/inventory.yml" site.yml
```

**Stage 2 (Terraform) - Application Infrastructure:**

```bash
# Navigate to stage2 within container
cd stage2

# Initialize Terraform (one-time setup)
terraform workspace select <workspace-name>
terraform init

# Deploy infrastructure
terraform plan    # Review deployment plan
terraform apply   # Deploy infrastructure stack
```

**Quality Checks:**

- **Pre-commit hooks**: `npm run precommit:run` (run all file checks)
- **SSH key management**: Use `ssh-add` for passphrase-protected keys

### Development Environment

- **Container Workspace**: `/srv` (project root mounted)
- **SSH Keys**: `~/.ssh` mounted for Git and server access
- **Kubernetes Config**: Copied to `container/root/.kube/config` after Stage 1
- **Required Ports**: SSH (non-22), Kubernetes API (6443), application ingress (80/443)

## Configuration Management

**Environment Variables (.env file):**

Critical configuration managed through environment variables:

```bash
# Kubernetes cluster configuration
kubernetes_cluster_type=kubeadm    # kubeadm, k3s, or minikube
server_ssh_host=192.168.1.100      # Target server IP
server_ssh_user=ubuntu             # SSH username
server_ssh_port=2222               # SSH port (must not be 22)

# Architecture support
host_machine_architecture=amd64    # amd64 or arm64

# Additional configuration
docker_default_data_path=/var/lib/docker
etc_hosts_json=[]                  # Custom host entries
```

**Terraform Variables:**

Extensive variable system in `stage2/variables.tf` covering:

- Network configuration (domains, IPs, ingress settings)
- Storage settings (Longhorn, MinIO capacity)
- Application configuration (GitLab, monitoring, auth)
- Resource limits and security settings

**Configuration Best Practices:**

When adding new configuration options:

1. Add to appropriate variable files with type validation
2. Include sensible default values
3. Document variable purpose and constraints
4. Update environment variable mappings
5. Test with both default and custom values

## Code Style & Infrastructure Standards

**File Organization:**

- **Ansible**: Follow role-based structure with tasks, templates, defaults
- **Terraform**: Modular approach with separate directories per service
- **Templates**: Use `.j2` for Ansible Jinja2, `.tftpl` for Terraform templates
- **Variables**: Consistent naming with underscores, descriptive prefixes

**Naming Conventions:**

- **Resources**: Use consistent prefixes (e.g., `gitlab_`, `prometheus_`, `minio_`)
- **Files**: Use kebab-case for playbooks, snake_case for variables
- **Domains**: Follow pattern `service.domain.local` for local services

**Version Management:**

- **Tool Versions**: Explicitly pinned in Dockerfile and inventory files
- **Kubernetes**: Version compatibility maintained across kubeadm, kubectl, CNI
- **Helm Charts**: Version pinning in Terraform helm_release resources

**Security Standards:**

- **Secrets**: Never commit sensitive data; use Terraform Cloud/environment variables
- **SSH**: Key-based authentication required, non-standard ports enforced
- **TLS**: Let's Encrypt certificates for all ingress endpoints
- **RBAC**: Proper role-based access control for all services

## Infrastructure Components

**Core Kubernetes Stack:**

1. **Cluster Options**:
   - **kubeadm**: Production-ready, full control, recommended for AMD64
   - **k3s**: Lightweight, good for resource-constrained environments
   - **minikube**: Development/testing, local development workflows

2. **Networking**: Cilium CNI for kubeadm, built-in for k3s/minikube

3. **Storage**: Longhorn distributed storage with configurable data paths

**Application Services:**

1. **Ingress & Security**:
   - NGINX Ingress Controller with MetalLB load balancing
   - cert-manager with Let's Encrypt integration
   - OAuth2 proxy with Auth0 authentication

2. **CI/CD & DevOps**:
   - GitLab platform with registry, runners, and object storage
   - ArgoCD for GitOps workflows
   - MinIO for S3-compatible object storage

3. **Monitoring & Observability**:
   - Prometheus stack (Prometheus, Grafana, AlertManager)
   - Elasticsearch stack (ECK operator, Kibana, Filebeat)
   - ElastAlert2 for log-based alerting
   - Kubecost for cost monitoring

4. **Networking & Access**:
   - Tailscale mesh VPN integration
   - WireGuard VPN server with web UI
   - Custom CoreDNS configuration for local domains

## Deployment Workflows

**Initial Setup Workflow:**

1. **Prerequisites**:
   - Ubuntu AMD64 server with SSH key access
   - Non-standard SSH port (not 22)
   - Terraform Cloud workspace configured
   - Domain/DNS setup for local services

2. **Environment Preparation**:

   ```bash
   cp .env.sample .env    # Configure environment
   npm run repo:setup     # Install dependencies
   ```

3. **Stage 1 Execution**:

   ```bash
   npm run docker:exec
   cd stage1
   ansible-playbook --ask-become-pass -i "inventories/inventory.yml" site.yml
   ```

4. **Stage 2 Execution**:

   ```bash
   cd stage2
   terraform workspace select <workspace>
   terraform init && terraform apply
   ```

**Maintenance & Updates:**

- **Security Updates**: Regular package updates via Ansible host_setup role
- **Application Updates**: Terraform plan/apply with updated chart versions
- **Backup Strategy**: GitLab automated backups to MinIO object storage
- **Monitoring**: Prometheus alerts for system health and capacity

## Troubleshooting

**Common Issues:**

1. **ServiceMonitor CRD Error**:

   ```bash
   # In stage2/monitoring/prometheus-stack.tf, within the helm_release resource
   # for kube-prometheus-stack, temporarily add the following parameter:
   # reuse_values = true
   # Then re-run: terraform apply
   ```

2. **GitLab Registry Storage Full**:

   ```bash
   # Expand MinIO PVCs:
   kubectl edit -nminio-tenant pvc data{0,1,2,3}-minio-tenant-pool-0-0
   ```

3. **SSH Connection Issues**:

   ```bash
   # Add SSH key if using passphrase:
   eval "$(ssh-agent)"
   ssh-add
   ```

4. **Architecture Compatibility**:
   - GitLab only supports AMD64; automatically skipped on ARM64
   - Other services support both AMD64 and ARM64

## Security & Best Practices

**Infrastructure Security:**

- **Server Hardening**: fail2ban, UFW firewall, snap removal, secure SSH
- **Network Security**: Non-standard SSH ports, ingress-only application access
- **Data Protection**: TLS everywhere, encrypted storage volumes
- **Access Control**: OAuth2 proxy authentication for all web services

**Operational Security:**

- **Secrets Management**: Terraform Cloud variables, never committed to Git
- **Regular Updates**: Automated package updates and security patching
- **Monitoring**: Comprehensive alerting for security and operational events
- **Backup Strategy**: Automated GitLab backups with retention policies

**Development Security:**

- **SSH Key Management**: Key-based authentication, proper key rotation
- **Container Security**: Alpine base images, minimal package installation
- **Code Quality**: Pre-commit hooks, infrastructure validation

## Git Workflow

- **Quality Gates**: Always run `npm run precommit:run` before commits
- **Container Testing**: Test Ansible/Terraform changes in container environment
- **Version Control**: Never commit `.env` files or sensitive configuration
- **Branch Strategy**: Feature branches for infrastructure changes
- **Review Process**: Infrastructure changes require careful review due to impact

## Architecture Notes

- **Single-Node Focus**: Optimized for homelab environments, not production clusters
- **Resource Efficiency**: Carefully tuned resource requests and limits
- **Local Development**: Full development environment in containerized tooling
- **GitOps Ready**: ArgoCD integration for application lifecycle management
- **Hybrid Cloud**: Supports both local and cloud-based storage backends
- **Extensibility**: Modular Terraform design for easy service addition/removal

This infrastructure provides a production-grade homelab environment suitable for development, learning, and small-scale production workloads with enterprise-grade tooling and security practices.
