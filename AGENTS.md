# AGENTS.md: AI Agent Context

This document provides essential context for AI models interacting with this codebase. For full documentation, see <https://chrisleekr.github.io/homelab-infrastructure/>.

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
| Add stage0 cloud provider | `stage0/<provider>/` | Create `*.tf`, add an account map to `stage0/variables.tf`, add a `module` block to `stage0/main.tf` per account, add `docs/stage0/<provider>.md` |
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

## Docs & Comments

Default to terse. Comments and docs explain WHY; the code already shows WHAT. Prefer the shortest version that keeps a future reader from reintroducing the bug.

- **State the rule, not the investigation.** Keep the invariant and the non-obvious trap. Drop the reasoning walkthrough that led there.
- **No evidence transcripts in files.** Probe output, HTTP codes, "verified live", and before/after comparisons belong in the MR description, not in `.tf` or README prose. Git blame links the two.
- **Say it once.** Each fact gets one home: `.tf` comments explain the mechanism for whoever edits that code; the module README covers operator-facing behavior (what is exposed, how to verify). Cross-reference instead of restating.
- **No changelogs in docs.** Docs describe current state. Rename a variable and just rewrite the table; git history is the changelog.
- **Variable descriptions are one or two sentences.** Longer rationale goes in a comment above the block.
- **Skip caveats about caveats.** If a cited doc needs walking back, cite a better source instead.
- **No em dashes, U+2014.** In any tracked text file: prose, Mermaid labels, `mkdocs.yml` nav titles, and `.tf` / `.yml` / `.sh` comments. Use a comma, colon, full stop or parentheses. `scripts/check-docs.py` enforces it and names the file, line and column.
- **Never hard wrap Markdown.** One line per paragraph, list item and quoted line, however long it runs. Wrapping is the reader's editor setting; a reflowed paragraph buries the real edit in a block of changed lines. `scripts/check-docs.py` enforces it and names the continuation line.

## Version Sources of Truth

| Type | Location |
|------|----------|
| Container tools (kubectl, helm, terraform) | `Dockerfile` ARG statements |
| Kubernetes components (kubeadm, containerd, cilium) | `stage1/inventories/inventory.yml` |
| Helm chart versions | Individual `helm_release` resources in `stage2/*/` |

## AI-Specific Notes

- **GitLab AMD64 only**: Check `host_machine_architecture` variable; GitLab skipped on ARM64
- **Module dependencies**: Defined in `stage2/main.tf` - respect `depends_on` chains
- **stage0 is optional**: a separate root, one Terraform Cloud workspace `homelab-stage0` holding every cloud account, each selected in code by an aliased provider and a module block. A LAN-only cluster never runs it. New Terraform directories need a committed `.terraform.lock.hcl` covering every platform that stage locks (stage0 locks three, including `linux_arm64`)
- **Validation**: Always run `task precommit` before suggesting commits
- **Secrets**: Never hardcode; store in Bitwarden Secrets Manager (see docs/operations/bitwarden-secrets.md), injected at runtime; `.env` holds only the bws bootstrap values, `BWS_ACCESS_TOKEN` and the optional `BWS_PROJECT_ID`
- **Pre-commit hooks**: ansible-lint, terraform_fmt, terraform_validate, trivy, gitleaks

## Security & Best Practices

**Infrastructure Security:**

- **Server Hardening**: fail2ban, UFW firewall, snap removal, secure SSH
- **Network Security**: Non-standard SSH ports, ingress-only application access
- **Data Protection**: TLS everywhere, encrypted storage volumes
- **Access Control**: OAuth2 proxy authentication for all web services

**Operational Security:**

- **Secrets Management**: Bitwarden Secrets Manager (bws), never committed to Git
- **Regular Updates**: Automated package updates and security patching
- **Monitoring**: Comprehensive alerting for security and operational events
- **Backup Strategy**: Automated GitLab backups with retention policies

**Development Security:**

- **SSH Key Management**: Key-based authentication, proper key rotation
- **Container Security**: Alpine base images, minimal package installation
- **Code Quality**: Pre-commit hooks, infrastructure validation
