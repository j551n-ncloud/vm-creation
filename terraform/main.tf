terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
  required_version = ">= 1.5.0"
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_tls_insecure

  ssh {
    agent       = true
    private_key = var.proxmox_ssh_private_key != "" ? file(pathexpand(var.proxmox_ssh_private_key)) : null
  }
}
