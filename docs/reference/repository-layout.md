# Repository layout

```text
homelab-infrastructure/
├── stage1/                       # Ansible: host setup and Kubernetes bootstrap
│   ├── ansible.cfg               # local_tmp is set to /tmp, see below
│   ├── site.yml                  # the six plays
│   ├── inventories/
│   │   └── inventory.yml         # host groups and every component version pin
│   ├── roles/                    # 10 roles
│   ├── handlers/                 # 6 handler files, imported per play
│   ├── cloud-init/raspberry-pi/  # worker bootstrap examples
│   ├── tests/                    # test_upgrade_ordering.py
│   └── requirements*.txt|yml     # Python and Ansible Galaxy dependencies
├── stage2/                       # Terraform: the platform
│   ├── main.tf                   # module orchestration and the depends_on DAG
│   ├── variables.tf              # every input variable, ~38 KB
│   ├── output.tf
│   ├── providers.tf
│   ├── backend.tf                # Terraform Cloud
│   └── <module>/                 # 19 module directories
├── docs/                         # this site
│   ├── requirements.txt          # the MkDocs pin
│   └── stylesheets/extra.css
├── scripts/                      # helper scripts
│   ├── sync-versions.sh          # version drift gate
│   ├── check-docs.py             # docs coverage, citation and nav gate
│   ├── tests/                    # self-test for check-docs.py
│   ├── bump-versions.sh
│   ├── docker-build.sh, docker-run.sh, repo-setup.sh
│   └── container/root/           # files baked into the image
├── mkdocs.yml
├── Dockerfile                    # tool versions live in ARG statements
├── Taskfile.yml                  # the command interface
├── .pre-commit-config.yaml
├── .gitlab-ci.yml                # build, scan, docs gate
├── .github/workflows/            # lint, container scan, docs publish, version sync
└── .env.example                  # only the two Bitwarden values
```

## Files that are not where you would expect

| File | Note |
|---|---|
| Module documentation | Under `docs/stage2/`, **not** in the module directories. The directories hold `.tf` only. |
| Version pins | Split across `Dockerfile` and `stage1/inventories/inventory.yml`. See [Version pins](versions.md). |
| `AGENTS.md` | Stays at the repo root, with `CLAUDE.md`, `AGENT.md`, `GEMINI.md`, `.cursorrules` and `.github/copilot-instructions.md` as symlinks to it. Mirrored onto this site. |
| `CONTRIBUTING.md`, `SECURITY.md` | Stay at the root, where GitHub's community-profile features read them. Mirrored onto this site. |
| `container/root/` | Gitignored. Where the fetched kubeconfig lands and what the tooling container mounts. |

!!! note "`stage1/ansible.cfg` sets `local_tmp = /tmp/.ansible/tmp`"

    The container bind-mounts `/root` from the Docker host, and `fcntl.flock` is not enforced on that filesystem. Unenforced flock breaks the AnsiballZ module-cache mutex, so concurrent workers race on a shared `-part` file and one loses with `ENOENT`. Moving controller-side temp work to `/tmp` puts it on a filesystem where flock works.

## Generated and ignored

`site/`, `.venv-docs/`, `.task/`, `container/root`, `.env`, `**/.terraform`, `*.tfvars`, `**/terraform.tfstate`, `*.bak`.
