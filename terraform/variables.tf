variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g. https://pve01:8006)"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token (user@realm!tokenid=secret)"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification for self-signed certs"
  type        = bool
  default     = true
}

variable "proxmox_ssh_private_key" {
  description = "Path to SSH private key for Proxmox nodes (optional, leave empty if using agent or API-only)"
  type        = string
  default     = ""
}

variable "proxmox_nodes" {
  description = "List of Proxmox nodes to distribute LXCs across"
  type        = list(string)
  default     = ["pve01"]
}

variable "lxc_password" {
  description = "Root password for LXC containers"
  type        = string
  sensitive   = true
}

variable "lxc_template" {
  description = "LXC template path in Proxmox (run scripts/proxmox-setup-token.sh first to download it)"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
}

variable "lxc_storage" {
  description = "Storage pool for LXC containers"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Network bridge for containers"
  type        = string
  default     = "vmbr0"
}

variable "ip_gateway" {
  description = "Default gateway for containers"
  type        = string
  default     = "192.168.1.1"
}

variable "services" {
  description = "Map of services to create LXCs for"
  type = map(object({
    vmid    = number
    ip      = string
    memory  = number
    disk_gb = number
    cores   = number
    node    = string
  }))
  default = {
    "vault" = {
      vmid    = 200
      ip      = "192.168.1.200"
      memory  = 1024
      disk_gb = 10
      cores   = 1
      node    = "pve01"
    }
  }
}

variable "gitlab_url" {
  description = "URL of the existing GitLab instance (e.g. https://gitlab.example.com)"
  type        = string
}

variable "runner_lxcs" {
  description = "GitLab Runner LXC per node"
  type = map(object({
    vmid    = number
    ip      = string
    memory  = number
    disk_gb = number
    cores   = number
  }))
  default = {
    "pve01" = {
      vmid    = 300
      ip      = "192.168.1.300"
      memory  = 1024
      disk_gb = 20
      cores   = 2
    }
  }
}
