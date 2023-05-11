terraform {
  backend "s3" {
    bucket         = "okd4-aws-dev-tf-state"
    key            = "global/okd4-hetzner/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "okd4-aws-dev-tf-lock"
  }
}

module "ignition" {
  source         = "./modules/hcloud_instance"
  instance_count = var.bootstrap == true ? 1 : 0
  location       = var.location
  name           = "ignition"
  cluster_url    = local.cluster_url
  image          = data.hcloud_image.debian.id
  user_data      = file("templates/cloud-init.tpl")
  ssh_keys       = data.hcloud_ssh_keys.all_keys.ssh_keys.*.name
  server_type    = "cx11"
  subnet         = hcloud_network_subnet.subnet.id
}

module "bootstrap" {
  source         = "./modules/hcloud_coreos"
  instance_count = var.bootstrap == true ? 1 : 0
  location       = var.location
  name           = "bootstrap"
  cluster_url    = local.cluster_url
  image          = data.hcloud_image.image.id
  image_name     = var.image
  server_type    = "cx41"
  subnet         = hcloud_network_subnet.subnet.id
  ignition_url   = var.bootstrap == true ? "http://ignition01.${local.cluster_url}/bootstrap.ign" : ""
}

module "master" {
  source         = "./modules/hcloud_coreos"
  instance_count = var.replicas_master
  location       = var.location
  name           = "master"
  cluster_url    = local.cluster_url
  image          = data.hcloud_image.image.id
  image_name     = var.image
  server_type    = "cx41"
  labels = {
    "okd.io/node"    = "true",
    "okd.io/master"  = "true",
    "okd.io/ingress" = "true"
  }
  delete_protection = var.bootstrap == false ? true : false
  # Manually add apply_to for the labels, until tf_hcloud allows apply_to in the firewall
  firewall_ids    = var.bootstrap == false ? [data.hcloud_firewall.okd-base[0].id, data.hcloud_firewall.okd-master[0].id, data.hcloud_firewall.okd-ingress[0].id] : []
  subnet          = hcloud_network_subnet.subnet.id
  ignition_url    = "https://api-int.${local.cluster_url}:22623/config/master"
  ignition_cacert = local.ignition_master_cacert
}

module "worker" {
  source         = "./modules/hcloud_coreos"
  instance_count = var.replicas_worker
  location       = var.location
  name           = "worker"
  cluster_url    = local.cluster_url
  image          = data.hcloud_image.image.id
  image_name     = var.image
  server_type    = "cx41"
  labels = {
    "okd.io/node"    = "true",
    "okd.io/ingress" = "true"
    "okd.io/worker"  = "true"
  }
  delete_protection = var.bootstrap == false ? true : false
  # Manually add apply_to for the labels, until tf_hcloud allows apply_to in the firewall
  firewall_ids    = var.bootstrap == false ? [data.hcloud_firewall.okd-base[0].id, data.hcloud_firewall.okd-ingress[0].id] : []
  subnet          = hcloud_network_subnet.subnet.id
  ignition_url    = "https://api-int.${local.cluster_url}:22623/config/worker"
  ignition_cacert = local.ignition_worker_cacert
}

# https://docs.okd.io/4.11/installing/installing_bare_metal/installing-bare-metal.html
# In OKD 4.4 and later, you do not need to specify etcd host and SRV records in your DNS configuration.
module "dns_lb_records" {
  source = "./modules/hcloud_dns"
  type   = "CNAME"
  records = {
    "api.${local.cluster_url}."      = "lb01.${local.cluster_url}."
    "api-int.${local.cluster_url}."  = "lb01.${local.cluster_url}."
    "registry.${local.cluster_url}." = "lb01.${local.cluster_url}."
    "console.${local.cluster_url}."  = "lb01.${local.cluster_url}."
    "*.${local.cluster_url}."        = "lb01.${local.cluster_url}."
  }
  depends_on = [
    module.lb
  ]
}

module "installer" {
  source          = "./modules/installer"
  domain          = var.domain
  cluster_name    = var.cluster_name
  replicas_master = var.replicas_master
  replicas_worker = var.replicas_worker
  postinstall     = var.postinstall
  hcloud_token    = var.HCLOUD_TOKEN
}
