# Loadbalancer implementation
data "template_file" "cloud_init" {
  template = file("templates/cloud-init-lb.tpl")

  vars = {
    masters = join(",", concat(module.bootstrap.server_names, module.master.server_names))
    workers = join(",", module.worker.server_names)
  }
}

data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  # Main cloud-config configuration file.
  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init.rendered
  }
}

module "lb" {
  source         = "./modules/hcloud_instance"
  instance_count = 1
  location       = var.location
  name           = "lb"
  cluster_url    = local.cluster_url
  image          = data.hcloud_image.debian.id
  user_data      = data.template_cloudinit_config.config.rendered
  ssh_keys       = data.hcloud_ssh_keys.all_keys.ssh_keys.*.name
  # to update DNS record
  dns_record_update = data.template_cloudinit_config.config.rendered
  server_type       = "cx21"
  delete_protection = var.bootstrap == false ? true : false
  firewall_ids      = var.bootstrap == false ? [data.hcloud_firewall.okd-base[0].id, data.hcloud_firewall.okd-master[0].id, data.hcloud_firewall.lb[0].id] : []
  subnet            = hcloud_network_subnet.lb_subnet.id
}


#####
## Native Hetzner Loadbalancer can't be used because there is no way to restrict access to it.
#####

# resource "hcloud_load_balancer" "lb" {
#   name               = "lb.${local.cluster_url}"
#   load_balancer_type = "lb11"
#   location           = var.location
#   dynamic "target" {
#     for_each = concat(module.master.server_ids, module.worker.server_ids, module.bootstrap.server_ids)
#     content {
#       type      = "server"
#       server_id = target.value
#     }
#   }
# }

# resource "hcloud_load_balancer_network" "lb_network" {
#   load_balancer_id = hcloud_load_balancer.lb.id
#   subnet_id        = hcloud_network_subnet.lb_subnet.id
#   ip               = "192.168.254.254"
# }

# resource "hcloud_load_balancer_service" "lb_api" {
#   load_balancer_id = hcloud_load_balancer.lb.id
#   protocol         = "tcp"
#   listen_port      = 6443
#   destination_port = 6443

#   health_check {
#     protocol = "tcp"
#     port     = 6443
#     interval = 10
#     timeout  = 1
#     retries  = 3
#   }
# }

# resource "hcloud_load_balancer_service" "lb_mcs" {
#   load_balancer_id = hcloud_load_balancer.lb.id
#   protocol         = "tcp"
#   listen_port      = 22623
#   destination_port = 22623

#   health_check {
#     protocol = "tcp"
#     port     = 22623
#     interval = 10
#     timeout  = 1
#     retries  = 3
#   }
# }

# resource "hcloud_load_balancer_service" "lb_ingress_http" {
#   load_balancer_id = hcloud_load_balancer.lb.id
#   protocol         = "tcp"
#   listen_port      = 80
#   destination_port = 80

#   health_check {
#     protocol = "tcp"
#     port     = 80
#     interval = 10
#     timeout  = 1
#     retries  = 3
#   }
# }

# resource "hcloud_load_balancer_service" "lb_ingress_https" {
#   load_balancer_id = hcloud_load_balancer.lb.id
#   protocol         = "tcp"
#   listen_port      = 443
#   destination_port = 443

#   health_check {
#     protocol = "tcp"
#     port     = 443
#     interval = 10
#     timeout  = 1
#     retries  = 3
#   }
# }
