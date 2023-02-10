module "ignition" {
  source         = "./modules/hcloud_instance"
  instance_count = var.bootstrap == true ? 1 : 0
  location       = var.location
  name           = "ignition"
  cluster_url    = local.cluster_url
  dns_api_token  = var.dns_api_token
  dns_zone_id    = var.dns_zone_id
  image          = "ubuntu-20.04"
  user_data      = file("templates/cloud-init.tpl")
  ssh_keys       = data.hcloud_ssh_keys.all_keys.ssh_keys.*.name
  server_type    = "cx11"
  subnet         = hcloud_network_subnet.subnet.id
}

module "bootstrap" {
  source          = "./modules/hcloud_coreos"
  instance_count  = var.bootstrap == true ? 1 : 0
  location        = var.location
  name            = "bootstrap"
  cluster_url     = local.cluster_url
  dns_api_token   = var.dns_api_token
  dns_zone_id     = var.dns_zone_id
  dns_internal_ip = false
  image           = data.hcloud_image.image.id
  image_name      = var.image
  server_type     = "cx41"
  subnet          = hcloud_network_subnet.subnet.id
  ignition_url    = var.bootstrap == true ? "http://ignition01.${local.cluster_url}/bootstrap.ign" : ""
}

module "master" {
  source          = "./modules/hcloud_coreos"
  instance_count  = var.replicas_master
  location        = var.location
  name            = "master"
  cluster_url     = local.cluster_url
  dns_api_token   = var.dns_api_token
  dns_zone_id     = var.dns_zone_id
  dns_internal_ip = false
  image           = data.hcloud_image.image.id
  image_name      = var.image
  server_type     = "cx41"
  labels = {
    "okd.io/node"    = "true",
    "okd.io/master"  = "true",
    "okd.io/ingress" = "true"
  }
  # Manually add apply_to for the labels, until tf_hcloud allows apply_to in the firewall
  # firewall_ids    = [hcloud_firewall.okd-base.id, hcloud_firewall.okd-master.id, hcloud_firewall.okd-ingress.id]
  subnet          = hcloud_network_subnet.subnet.id
  ignition_url    = "https://api-int.${local.cluster_url}:22623/config/master"
  ignition_cacert = local.ignition_master_cacert
}

module "worker" {
  source          = "./modules/hcloud_coreos"
  instance_count  = var.replicas_worker
  location        = var.location
  name            = "worker"
  cluster_url     = local.cluster_url
  dns_api_token   = var.dns_api_token
  dns_zone_id     = var.dns_zone_id
  dns_internal_ip = false
  image           = data.hcloud_image.image.id
  image_name      = var.image
  server_type     = "cx41"
  labels = {
    "okd.io/node"    = "true",
    "okd.io/ingress" = "true"
    "okd.io/worker"  = "true"
  }
  # Manually add apply_to for the labels, until tf_hcloud allows apply_to in the firewall
  # firewall_ids    = [hcloud_firewall.okd-base.id, hcloud_firewall.okd-ingress.id]
  subnet          = hcloud_network_subnet.subnet.id
  ignition_url    = "https://api-int.${local.cluster_url}:22623/config/worker"
  ignition_cacert = local.ignition_worker_cacert
}

# https://docs.okd.io/4.11/installing/installing_bare_metal/installing-bare-metal.html
# In OKD 4.4 and later, you do not need to specify etcd host and SRV records in your DNS configuration.
module "dns_a_records" {
  source    = "./modules/hcloud_dns"
  api_token = var.dns_api_token
  zone_id   = var.dns_zone_id
  type      = "A"
  records = {
    "api.${local.cluster_url}."     = hcloud_load_balancer.lb.ipv4
    "api-int.${local.cluster_url}." = hcloud_load_balancer.lb.ipv4
    "apps.${local.cluster_url}."    = hcloud_load_balancer.lb.ipv4
    "*.apps.${local.cluster_url}."  = hcloud_load_balancer.lb.ipv4
  }
  # depends_on = [
  #   module.ignition,
  #   hcloud_load_balancer.lb
  # ]
}

module "installer" {
  source          = "./modules/installer"
  count           = var.generate_okd_configs ? 1 : 0
  domain          = var.domain
  cluster_name    = var.cluster_name
  replicas_master = var.replicas_master
  replicas_worker = var.replicas_worker
  public_ssh_key  = var.public_ssh_key
}
