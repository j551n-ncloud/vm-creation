output "service_lxc_ips" {
  description = "IP addresses of service LXCs"
  value = {
    for k, v in proxmox_virtual_environment_container.services :
    k => v.initialization[0].ip_config[0].ipv4[0].address
  }
}

output "runner_lxc_ips" {
  description = "IP addresses of runner LXCs"
  value = {
    for k, v in proxmox_virtual_environment_container.runners :
    k => v.initialization[0].ip_config[0].ipv4[0].address
  }
}

output "gitlab_vm_ip" {
  description = "IP address of GitLab CE VM"
  value       = var.gitlab_vm.ip
}

output "vault_ip" {
  description = "Vault LXC IP"
  value       = try(var.services["vault"].ip, "not configured")
}

output "ansible_inventory" {
  description = "Ansible inventory snippet for generated hosts"
  value = templatefile("${path.module}/inventory.tpl", {
    gitlab_ip   = var.gitlab_vm.ip
    vault_ip    = try(var.services["vault"].ip, "")
    services    = var.services
    runner_lxcs = var.runner_lxcs
  })
}
