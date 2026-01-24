# Contributing to Homelab Infrastructure

Thank you for your interest in contributing to this project. This document provides guidelines for contributing.

## Development Environment

### Prerequisites

- Docker installed on your machine
- SSH key configured for server access
- Terraform Cloud account (for state management)

### Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/chrisleekr/homelab-infrastructure.git
   cd homelab-infrastructure
   ```

2. Install dependencies:

   ```bash
   task repo:setup
   ```

3. Build and enter the development container:

   ```bash
   task docker:build
   task docker:exec
   ```

### Container Workspace

- **Workspace root**: `/srv`
- **SSH keys**: `~/.ssh` mounted for Git and server access
- **Kubernetes config**: `container/root/.kube/config`

## Code Style Guidelines

### Terraform

- Use snake_case for resource names and variables
- Use `.tftpl` extension for Terraform templates
- Pin Helm chart versions in `helm_release` resources
- Include type, description, and default for all variables
- Add validation blocks where appropriate

### Ansible

- Follow role-based structure: `tasks/`, `templates/`, `defaults/`
- Use `.j2` extension for Jinja2 templates
- Use kebab-case for playbook file names
- Use snake_case for variable names

### Naming Conventions

- **Resources**: Use consistent prefixes (e.g., `gitlab_`, `prometheus_`, `minio_`)
- **Domains**: Follow pattern `service.domain.local`

## Pre-commit Hooks

This project uses pre-commit hooks to ensure code quality. Always run before committing:

```bash
task precommit
```

The following hooks are configured:

| Hook | Purpose |
|------|---------|
| `ansible-lint` | Validate Ansible playbooks and roles |
| `terraform_fmt` | Format Terraform files |
| `terraform_validate` | Validate Terraform configuration |
| `terraform_trivy` | Security scanning for Terraform |
| `terraform_tflint` | Lint Terraform files |
| `detect-private-key` | Prevent committing private keys |
| `gitleaks` | Detect secrets in code |

## Pull Request Process

1. **Create a feature branch** from `master`:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following the code style guidelines.

3. **Run pre-commit hooks**:

   ```bash
   task precommit
   ```

4. **Test your changes** in the container environment.

5. **Commit your changes** with a descriptive message:

   ```bash
   git commit -m "Add feature: description of changes"
   ```

6. **Push to your fork** and create a pull request.

7. **Describe your changes** in the PR description:
   - What problem does this solve?
   - How was it tested?
   - Any breaking changes?

## Adding New Modules

### Terraform Module

1. Create directory: `stage2/<module-name>/`
2. Create required files:
   - `main.tf` or `<service>.tf` - Main resources
   - `variables.tf` - Module variables (if needed)
   - `provider.tf` - Provider configuration (if needed)
   - `templates/` - Template files (if needed)
   - `README.md` - Module documentation
3. Add module to `stage2/main.tf` with appropriate dependencies
4. Add enable variable to `stage2/variables.tf` if optional

### Ansible Role

1. Create directory: `stage1/roles/<role-name>/`
2. Create required files:
   - `tasks/main.yml` - Task definitions
   - `defaults/main.yml` - Default variables
   - `templates/` - Jinja2 templates (if needed)
3. Add role to appropriate playbook in `stage1/`

## Security Guidelines

- **Never commit secrets** - Use Terraform Cloud variables or `.env` files (gitignored)
- **Never commit `.env` files** - They contain sensitive configuration
- **Use SSH keys** - Never commit private keys
- **Pin versions** - Always pin tool and chart versions

## Questions?

If you have questions about contributing, please open an issue for discussion.
