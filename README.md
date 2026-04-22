# Proxmox VM Kickstart Playbook

This project provides an interactive Ansible playbook to provision virtual machines on a Proxmox cluster, with support for both real and dry-run (no-create) modes.

## Requirements
- Ansible (tested with ansible-core 2.20+)
- Access to a Proxmox API endpoint
- Python 3.x

## Usage

### 1. Inventory
A sample inventory file is provided:

```
[local]
localhost ansible_connection=local
```

### 2. Run the Playbook

#### Dry-run mode (no VM is created)
```
DRY_RUN=true ansible-playbook -i inventory.ini kickstart.yml
```

#### Real mode (creates a VM)
```
ansible-playbook -i inventory.ini kickstart.yml
```

### 3. Interactive Prompts
- You will be prompted for:
  - Proxmox realm (default or realm.de)
  - Proxmox user (enter username or username@realm)
  - Proxmox password or API token (prompted as needed)
  - Node, storage, bridge, VM name, CPU, RAM, disk size

### 4. Authentication
- You can use either a password or an API token for authentication.
- If you do not set environment variables, the playbook will prompt you interactively.
- To use environment variables, set:
  - `PROXMOX_API_BASE_URL`, `PROXMOX_USER`, `PROXMOX_PASSWORD` (or `PROXMOX_TOKEN` and `PROXMOX_SECRET`)

### 5. Notes
- The playbook is safe to run in dry-run mode for validation and planning.
- In real mode, a VM will be created on the selected Proxmox node.
- All choices are interactive unless you pre-set variables via environment or extra-vars.

## Troubleshooting
- If you see connection or authentication errors, check your Proxmox credentials and API endpoint.
- For local-only testing, always use dry-run mode.

## License
MIT
 
## Contributors

- Johannes Nguyen
