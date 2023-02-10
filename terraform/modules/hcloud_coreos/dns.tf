module "hcloud_server_dns_a_records" {
  count     = var.instance_count
  source    = "../hcloud_dns"
  api_token = var.dns_api_token
  zone_id   = var.dns_zone_id
  type      = "A"
  records = {
    "${element(hcloud_server.server.*.name, count.index)}." = element(hcloud_server.server.*.ipv4_address, count.index)
  }
  # depends_on = [
  #   hcloud_server.server
  # ]
}
