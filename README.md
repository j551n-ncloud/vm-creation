# GitOps Stack — Proxmox + GitLab + Vault

Fully automated GitOps stack on a Proxmox cluster. Terraform provisions LXC containers, Ansible configures them, GitLab CI/CD handles deployments, and Vault manages secrets.

> **Prerequisite:** A running GitLab instance is required. No GitLab VM is created by this stack.

## Architecture

```
Proxmox Cluster
├── LXC per Service   (Docker + Vault Agent + docker-compose)
├── LXC per Node      (GitLab Runner)
└── LXC Vault         (HashiCorp Vault, KV v2)

GitLab (existing instance)
└── services/         (submodule repo)
    └── vaultwarden/  (example service)
        ├── main      → Validation (lint, syntax)
        ├── stage     → Build + Staging deploy
        └── release   → Build + Production deploy
```

## Repository Structure

```
.
├── terraform/                  # Proxmox LXC provisioning (bpg/proxmox)
│   ├── main.tf
│   ├── lxc.tf                  # Service + Runner LXCs (nesting=true, keyctl=true)
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── ansible/
│   ├── init.yml                # Interactive init — runs everything end-to-end
│   ├── add-service.yml         # Add a new service (LXC + GitLab submodules)
│   ├── docker-install.yml
│   ├── runner-install.yml
│   ├── vault-setup.yml
│   ├── health-check.yml
│   ├── inventory/
│   │   └── proxmox_dynamic.yml # Dynamic inventory via Proxmox API
│   └── roles/
│       ├── docker_install/
│       ├── runner_install/
│       ├── vault_setup/
│       ├── lxc_create/
│       ├── proxmox_connect/
│       └── service_deploy/     # Deploy docker-compose + Vault AppRole
├── gitlab/
│   ├── .gitlab-ci.yml
│   ├── templates/
│   │   ├── validation.yml      # YAML, Dockerfile, Ansible, Terraform lint
│   │   ├── stage.yml           # Docker build + staging deploy + description update
│   │   └── release.yml         # Docker build + production deploy + rsync + description update
│   └── submodule-template/     # Copy this when creating a new service repo
│       ├── main/
│       ├── stage/
│       └── release/
├── services/                   # Git submodule (separate repo: ../services.git)
│   └── vaultwarden/
│       ├── docker-compose.yml
│       ├── vault-agent.hcl
│       ├── .env.example
│       └── secrets/
│           └── env.ctmpl
└── scripts/
    ├── deploy.sh               # SSH deploy with rsync backup option
    ├── health-check.sh         # Docker health → updates GitLab description
    └── update-description.sh  # Deploy info → updates GitLab description
```

## Quick Start

### 1. Clone with submodules

```bash
git clone --recurse-submodules <repo-url>
```

### 2. Configure Terraform

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform/terraform.tfvars with your Proxmox API token, node IPs, GitLab URL
```

### 3. Run the init playbook

```bash
ansible-playbook ansible/init.yml
```

The playbook prompts for:
- Proxmox API URL + token
- Proxmox nodes to use
- LXC root password
- GitLab URL + API token + runner registration token + project ID
- Vault root token (auto-generated if left empty)

It then runs in order: Terraform apply → Docker install → Runner register → Vault init → Health check setup → Push configs to GitLab.

### 4. Add a new service

```bash
ansible-playbook ansible/add-service.yml \
  -e service_name=my-service \
  -e service_vmid=202 \
  -e service_ip=192.168.1.202 \
  -e service_node=pve01 \
  -e service_port=8080
```

This creates the LXC, installs Docker, sets up Vault AppRole, creates the three GitLab submodule repos (`main`, `stage`, `release`), and deploys docker-compose.

## Deploy Flow

```
Push to <service>/main    →  Validation (lint yaml/dockerfile/ansible/terraform)
Push to <service>/stage   →  Docker build → push to registry
                          →  SSH into LXC → docker compose pull + up
                          →  GitLab description line 1: 🚀 STAGING | abc1234 | LXC:201 | deployed 2026-04-25 14:32
Push tag on <service>/release →  Docker build → push to registry
                              →  SSH into LXC → docker compose pull + up
                              →  rsync ./config/ to LXC (with timestamped backup)
                              →  GitLab description line 1: 🚀 PRODUCTION | v1.2.3 | LXC:201 | deployed 2026-04-25
                              →  GitLab description line 2: v1.2.3 | released 2026-04-25 | vaultwarden
```

## GitLab Project Description Format

Each service repo shows two lines, updated independently:

```
🚀 PRODUCTION | v1.2.3 | LXC:201 | deployed 2026-04-25 14:10 | vaultwarden
v1.2.3 | released 2026-04-25 | vaultwarden
✅ HEALTHY | LXC:201 pve01 | 2026-04-25 14:37
```

- **Line 1** — set by `update-description.sh` on every deploy (staging uses commit SHA, production uses git tag) — includes LXC ID
- **Line 2** — set by `update-description.sh` on production release only; shows the latest released version
- **Line 3** — set by `health-check.sh` cronjob every 5 minutes on the LXC

Each script reads the current description and preserves the other lines.

## Secrets (Vault)

Vault runs in its own LXC. Each service authenticates via AppRole (created automatically by `add-service.yml`):

```
secret/vaultwarden/config
  → admin_token
  → database_url
```

The Vault Agent sidecar container renders secrets into `/run/secrets/app.env` at runtime. The app container reads that file — no secrets ever stored in the image or the repo.

## Adding a Service to `services/`

1. Create a new folder inside `services/` (in the submodule repo)
2. Copy `services/vaultwarden/` as a starting point
3. Update `docker-compose.yml`, `vault-agent.hcl`, and `secrets/env.ctmpl`
4. Run `ansible-playbook ansible/add-service.yml -e service_name=<name> ...`

## scripts/deploy.sh Options

```
--host          Target LXC IP (required)
--service       Service name (required)
--tag           Docker image tag (default: latest)
--ssh-key       Path to SSH private key
--rsync-src     Local config path to sync
--rsync-dest    Remote destination path
--backup-dest   Remote path for timestamped rsync backups
--timeout       rsync network timeout in seconds (default: 30)
--bwlimit       rsync bandwidth limit in KB/s, 0=unlimited
```

## Requirements

| Tool | Version |
|---|---|
| Terraform | >= 1.5 |
| bpg/proxmox provider | ~> 0.66 |
| Ansible | >= 2.15 |
| community.general | latest |
| community.docker | latest |
| Docker | 24+ |
| Vault | 1.17+ |

## Contributors

- Johannes Nguyen
