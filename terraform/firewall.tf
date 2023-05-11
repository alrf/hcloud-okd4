data "hcloud_firewall" "okd-master" {
  count = var.bootstrap == true ? 0 : 1
  name  = "okd-master"
}

data "hcloud_firewall" "okd-base" {
  count = var.bootstrap == true ? 0 : 1
  name  = "okd-base"
}

data "hcloud_firewall" "okd-ingress" {
  count = var.bootstrap == true ? 0 : 1
  name  = "okd-ingress"
}

data "hcloud_firewall" "lb" {
  count = var.bootstrap == true ? 0 : 1
  name  = "lb"
}


# https://docs.okd.io/latest/installing/installing_platform_agnostic/installing-platform-agnostic.html#installation-network-connectivity-user-infra_installing-platform-agnostic
resource "hcloud_firewall" "okd-base" {
  name = "okd-base"
  # ICMP is always a good idea
  #
  # Network reachability tests
  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "ICMP"
  }
  # SSH
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = 22
    # OKD4 + VPN servers
    source_ips  = concat([for s in concat(module.master.ipv4_addresses, module.worker.ipv4_addresses, module.bootstrap.ipv4_addresses) : "${s}/32"], local.vpn_servers)
    description = "SSH"
  }
  # Metrics
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = 1936
    source_ips  = [for s in concat(module.master.ipv4_addresses, module.worker.ipv4_addresses, module.bootstrap.ipv4_addresses) : "${s}/32"]
    description = "Metrics"
  }
  # Host level services, including the node exporter on ports 9100-9101 and the Cluster Version Operator on port 9099.
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "9000-9999"
    source_ips  = [for s in concat(module.master.ipv4_addresses, module.worker.ipv4_addresses, module.bootstrap.ipv4_addresses) : "${s}/32"]
    description = "Host level services - tcp"
  }
  # The default ports that Kubernetes reserves
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "10250-10259"
    source_ips  = [for s in concat(module.master.ipv4_addresses, module.worker.ipv4_addresses, module.bootstrap.ipv4_addresses) : "${s}/32"]
    description = "Default k8s ports"
  }
  # openshift-sdn
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "10256"
    source_ips  = [for s in concat(module.master.ipv4_addresses, module.worker.ipv4_addresses, module.bootstrap.ipv4_addresses) : "${s}/32"]
    description = "openshift-sdn"
  }
  # VXLAN and Geneve
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "4789"
    source_ips  = [for s in concat(module.master.ipv4_addresses, module.worker.ipv4_addresses, module.bootstrap.ipv4_addresses) : "${s}/32"]
    description = "VXLAN and Geneve"
  }
  # VXLAN and Geneve
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "6081"
    source_ips  = [for s in concat(module.master.ipv4_addresses, module.worker.ipv4_addresses, module.bootstrap.ipv4_addresses) : "${s}/32"]
    description = "VXLAN and Geneve"
  }
  # Host level services, including the node exporter on ports 9100-9101.
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "9000-9999"
    source_ips  = [for s in concat(module.master.ipv4_addresses, module.worker.ipv4_addresses, module.bootstrap.ipv4_addresses) : "${s}/32"]
    description = "Host level services - udp"
  }
  # Kubernetes node port
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "30000-32767"
    source_ips  = [for s in concat(module.master.ipv4_addresses, module.worker.ipv4_addresses, module.bootstrap.ipv4_addresses) : "${s}/32"]
    description = "k8s node port - tcp"
  }
  # Kubernetes node port
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30000-32767"
    source_ips  = [for s in concat(module.master.ipv4_addresses, module.worker.ipv4_addresses, module.bootstrap.ipv4_addresses) : "${s}/32"]
    description = "k8s node port - udp"
  }
}


resource "hcloud_firewall" "okd-master" {
  name = "okd-master"

  # ICMP is always a good idea
  #
  # Network reachability tests
  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "ICMP"
  }
  # Kubernetes API
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = [for s in concat(module.lb.ipv4_addresses, module.master.ipv4_addresses, module.worker.ipv4_addresses, module.bootstrap.ipv4_addresses) : "${s}/32"]
    description = "k8s API"
  }
  # Machine config server
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22623"
    #source_ips  = [for s in [hcloud_load_balancer.lb.ipv4] : "${s}/32"]
    source_ips  = [for s in concat(module.lb.ipv4_addresses, module.worker.ipv4_addresses) : "${s}/32"]
    description = "Machine config server"
  }
  # etcd server and peer ports
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "2379-2380"
    source_ips  = [for s in module.master.ipv4_addresses : "${s}/32"]
    description = "etcd"
  }
}

resource "hcloud_firewall" "okd-ingress" {
  name = "okd-ingress"

  # ICMP is always a good idea
  #
  # Network reachability tests
  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "ICMP"
  }
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    #source_ips  = [for s in [hcloud_load_balancer.lb.ipv4] : "${s}/32"]
    source_ips  = [for s in module.lb.ipv4_addresses : "${s}/32"]
    description = "80 tcp"
  }
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    #source_ips  = [for s in [hcloud_load_balancer.lb.ipv4] : "${s}/32"]
    source_ips  = [for s in module.lb.ipv4_addresses : "${s}/32"]
    description = "443 tcp"
  }
}

resource "hcloud_firewall" "lb" {
  name = "lb"

  # ICMP is always a good idea
  #
  # Network reachability tests
  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "ICMP"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = concat([for s in concat(module.master.ipv4_addresses, module.worker.ipv4_addresses) : "${s}/32"], local.allowed_cidrs)
    description = "80 tcp"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = concat([for s in concat(module.master.ipv4_addresses, module.worker.ipv4_addresses) : "${s}/32"], local.allowed_cidrs)
    description = "443 tcp"
  }
  # Kubernetes API
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = concat([for s in concat(module.master.ipv4_addresses, module.worker.ipv4_addresses) : "${s}/32"], local.allowed_cidrs)
    description = "k8s API"
  }
}
