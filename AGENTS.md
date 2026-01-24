# AGENTS.md: AI Agent Context

This document provides essential context for AI models interacting with this codebase.
For full documentation, see [README.md](README.md).

## Quick Reference

**Key Files to Read First:**

- `stage2/main.tf` - Module dependencies and orchestration
- `stage2/variables.tf` - All Terraform input variables
- `Dockerfile` - Container tool versions (source of truth)
- `stage1/inventories/inventory.yml` - Kubernetes component versions

## Common Patterns

| Task | Location | Pattern |
|------|----------|---------|
| Add Terraform module | `stage2/<name>/` | Create `*.tf`, add to `main.tf` with dependencies |
| Add Helm chart | Module's `.tf` | Use `helm_release` resource with version pinning |
| Add Ansible role | `stage1/roles/<role>/` | Create `tasks/main.yml`, `defaults/main.yml`, `templates/` |
| Add variable | `stage2/variables.tf` | Include type, description, default, validation |
| Enable optional module | `stage2/main.tf` | Use `count = var.<module>_enable ? 1 : 0` |

## Before Making Changes

1. Run `task precommit` to validate
2. Check module dependencies in `stage2/main.tf`
3. Verify version compatibility in `Dockerfile` and `inventory.yml`

## Code Conventions

- **Terraform**: snake_case for resources/variables
- **Templates**: `.j2` (Ansible Jinja2), `.tftpl` (Terraform)
- **Domains**: `service.domain.local` pattern
- **Resources**: Use consistent prefixes (e.g., `gitlab_`, `prometheus_`, `minio_`)
- **Files**: kebab-case for playbooks, snake_case for variables

## Version Sources of Truth

| Type | Location |
|------|----------|
| Container tools (kubectl, helm, terraform) | `Dockerfile` ARG statements |
| Kubernetes components (kubeadm, containerd, cilium) | `stage1/inventories/inventory.yml` |
| Helm chart versions | Individual `helm_release` resources in `stage2/*/` |

## AI-Specific Notes

- **GitLab AMD64 only**: Check `host_machine_architecture` variable; GitLab skipped on ARM64
- **Module dependencies**: Defined in `stage2/main.tf` - respect `depends_on` chains
- **Validation**: Always run `task precommit` before suggesting commits
- **Secrets**: Never hardcode; use Terraform Cloud variables or `.env` (gitignored)
- **Pre-commit hooks**: ansible-lint, terraform_fmt, terraform_validate, trivy, gitleaks

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
