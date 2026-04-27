#!/usr/bin/env bash
# Run this on a Proxmox node (via SSH) before running ansible init.yml.
# Creates a Proxmox user + API token with the minimum required permissions.
set -euo pipefail

TERRAFORM_USER="${1:-terraform@pam}"
TOKEN_NAME="${2:-gitops}"

# Parse user and realm
USER_PART="${TERRAFORM_USER%%@*}"
REALM_PART="${TERRAFORM_USER##*@}"

echo "Creating Proxmox API token for Terraform/Ansible"
echo "  User:  ${TERRAFORM_USER}"
echo "  Token: ${TOKEN_NAME}"
echo ""

# Create user if it doesn't exist
if ! pveum user list | grep -q "^${TERRAFORM_USER}"; then
  pveum user add "${TERRAFORM_USER}" --comment "Terraform GitOps"
  echo "Created user: ${TERRAFORM_USER}"
else
  echo "User already exists: ${TERRAFORM_USER}"
fi

# Create a role with minimum required permissions
pveum role add TerraformGitOps \
  --privs "VM.Allocate,VM.Audit,VM.Config.Disk,VM.Config.CPU,VM.Config.Memory,VM.Config.Network,VM.Monitor,VM.PowerMgmt,Datastore.AllocateSpace,Datastore.Audit,Sys.Audit,SDN.Use" \
  2>/dev/null || \
pveum role modify TerraformGitOps \
  --privs "VM.Allocate,VM.Audit,VM.Config.Disk,VM.Config.CPU,VM.Config.Memory,VM.Config.Network,VM.Monitor,VM.PowerMgmt,Datastore.AllocateSpace,Datastore.Audit,Sys.Audit,SDN.Use"
echo "Role TerraformGitOps created/updated"

# Assign role to user on all resources
pveum acl modify / \
  --roles TerraformGitOps \
  --users "${TERRAFORM_USER}" \
  --propagate 1
echo "Role assigned to user on /"

# Create API token (privsep=0 inherits user permissions)
TOKEN_SECRET=$(pveum token add "${TERRAFORM_USER}" "${TOKEN_NAME}" \
  --privsep 0 \
  --comment "Terraform GitOps token" \
  --output-format json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['value'])" \
  || echo "TOKEN_ALREADY_EXISTS")

echo ""
if [[ "$TOKEN_SECRET" == "TOKEN_ALREADY_EXISTS" ]]; then
  echo "Token already exists. To regenerate, delete it first:"
  echo "  pveum token remove ${TERRAFORM_USER} ${TOKEN_NAME}"
  echo ""
  echo "Then re-run this script."
else
  echo "Add this to terraform.tfvars:"
  echo ""
  echo "  proxmox_api_token = \"${TERRAFORM_USER}!${TOKEN_NAME}=${TOKEN_SECRET}\""
fi

# Download LXC template if not already present
TEMPLATE="debian-12-standard_12.12-1_amd64.tar.zst"
if ! pveam list local 2>/dev/null | grep -q "${TEMPLATE}"; then
  echo ""
  echo "Downloading LXC template: ${TEMPLATE}"
  pveam update
  pveam download local "${TEMPLATE}"
  echo "Template downloaded."
else
  echo ""
  echo "LXC template already present: ${TEMPLATE}"
fi
