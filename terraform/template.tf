resource "proxmox_virtual_environment_download_file" "lxc_template" {
  for_each = toset(var.proxmox_nodes)

  node_name    = each.key
  content_type = "vztmpl"
  datastore_id = "local"
  url          = var.lxc_template_url

  overwrite = false
}
