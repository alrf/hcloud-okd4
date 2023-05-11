module "hcloud_server_dns_a_records" {
  count  = var.instance_count
  source = "../hcloud_dns"
  type   = "A"
  records = {
    "${element(hcloud_server.server.*.name, count.index)}." = element(hcloud_server.server.*.ipv4_address, count.index)
  }
}
