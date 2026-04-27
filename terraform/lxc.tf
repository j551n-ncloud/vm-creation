resource "proxmox_virtual_environment_container" "services" {
  for_each     = var.services
  node_name    = each.value.node
  vm_id        = each.value.vmid
  unprivileged = true

  description = "Service LXC: ${each.key}"
  tags        = ["gitops", each.key]

  initialization {
    hostname = each.key

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.ip_gateway
      }
    }

    user_account {
      password = var.lxc_password
    }
  }

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.lxc_storage
    size         = each.value.disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.lxc_template[each.value.node].id
    type             = "debian"
  }

  features {
    nesting = true
  }

  start_on_boot = true
  started       = true
}

resource "proxmox_virtual_environment_container" "runners" {
  for_each     = var.runner_lxcs
  node_name    = each.key
  vm_id        = each.value.vmid
  unprivileged = true

  description = "GitLab Runner: ${each.key}"
  tags        = ["gitops", "runner"]

  initialization {
    hostname = "runner-${each.key}"

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.ip_gateway
      }
    }

    user_account {
      password = var.lxc_password
    }
  }

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.lxc_storage
    size         = each.value.disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.lxc_template[each.key].id
    type             = "debian"
  }

  features {
    nesting = true
  }

  start_on_boot = true
  started       = true
}
