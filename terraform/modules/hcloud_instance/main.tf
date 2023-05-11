resource "hcloud_server" "server" {
  count              = var.instance_count
  name               = "${format("${var.name}%02d", count.index + 1)}.${var.cluster_url}"
  image              = var.image
  server_type        = var.server_type
  keep_disk          = var.keep_disk
  ssh_keys           = var.ssh_keys
  user_data          = var.user_data
  location           = var.location
  backups            = var.backups
  delete_protection  = var.delete_protection
  rebuild_protection = var.delete_protection
  firewall_ids       = var.firewall_ids
  # lifecycle {
  #   ignore_changes = [user_data, image]
  # }
  lifecycle {
    ignore_changes = [image]
  }
}

module "hcloud_server_dns_a_records" {
  count        = var.instance_count
  source       = "../hcloud_dns"
  force_update = var.dns_record_update
  type         = "A"
  records = {
    "${element(hcloud_server.server.*.name, count.index)}." = element(hcloud_server.server.*.ipv4_address, count.index)
  }
}

resource "hcloud_rdns" "dns-ptr-ipv4" {
  count      = var.instance_count
  server_id  = element(hcloud_server.server.*.id, count.index)
  ip_address = element(hcloud_server.server.*.ipv4_address, count.index)
  dns_ptr    = element(hcloud_server.server.*.name, count.index)
}

resource "hcloud_rdns" "dns-ptr-ipv6" {
  count      = var.instance_count
  server_id  = element(hcloud_server.server.*.id, count.index)
  ip_address = "${element(hcloud_server.server.*.ipv6_address, count.index)}1"
  dns_ptr    = element(hcloud_server.server.*.name, count.index)
}
