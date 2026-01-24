# Security Policy

## Supported Versions

This project is actively maintained. Security updates are applied to the latest version.

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

### How to Report

1. **Do not** open a public GitHub issue for security vulnerabilities.
2. Send a detailed report to the repository maintainer via GitHub's private vulnerability reporting feature or by opening a draft security advisory.
3. Include as much information as possible:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Acknowledgment**: You will receive an acknowledgment within 48 hours.
- **Updates**: We will keep you informed of the progress toward a fix.
- **Disclosure**: Once the vulnerability is fixed, we will coordinate with you on disclosure timing.

## Security Best Practices

This project implements the following security measures:

### Infrastructure Security

- **Server Hardening**: fail2ban, UFW firewall, snap removal, secure SSH
- **Network Security**: Non-standard SSH ports (not 22), ingress-only application access
- **Data Protection**: TLS certificates via Let's Encrypt, encrypted storage volumes
- **Access Control**: OAuth2 proxy authentication for web services

### Secrets Management

- Secrets are stored in Terraform Cloud variables, never in the repository
- `.env` files are gitignored
- Pre-commit hooks scan for accidentally committed secrets (gitleaks)

### Code Quality

- Pre-commit hooks validate all changes
- Trivy scans Terraform configurations for security issues
- Ansible-lint validates playbook security

## Security Scanning

This project uses the following security tools:

| Tool | Purpose |
|------|---------|
| Trivy | Container and Terraform security scanning |
| gitleaks | Detect secrets in code |
| detect-private-key | Prevent committing private keys |

Run security checks locally:

```bash
task precommit
```
