resource "proxmox_virtual_environment_vm" "gitlab" {
  node_name = var.gitlab_vm.node
  vm_id     = var.gitlab_vm.vmid
  name      = "gitlab-ce"
  tags      = ["gitops", "gitlab"]

  description = "GitLab CE self-hosted instance"

  cpu {
    cores = var.gitlab_vm.cores
    type  = "host"
  }

  memory {
    dedicated = var.gitlab_vm.memory
  }

  disk {
    datastore_id = var.vm_storage
    size         = var.gitlab_vm.disk_gb
    interface    = "scsi0"
    file_format  = "raw"
  }

  cdrom {
    file_id = var.gitlab_iso
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.gitlab_vm.ip}/24"
        gateway = var.ip_gateway
      }
    }
  }

  boot_order    = ["scsi0", "ide2"]
  on_boot       = true
  scsi_hardware = "virtio-scsi-pci"
}
