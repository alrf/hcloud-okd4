locals {
  cluster_url   = "${var.cluster_name}.${var.domain}"
  vpn_servers   = sort(yamldecode(trimspace(file("../allowed_cidrs.yaml")))["vpn_servers"])
  allowed_cidrs = sort(flatten(values(yamldecode(trimspace(file("../allowed_cidrs.yaml"))))))
}
