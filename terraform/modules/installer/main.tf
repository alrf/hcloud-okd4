data "template_file" "install_config_yaml" {
  template = <<-EOF
---
apiVersion: v1
baseDomain: '${var.domain}'
metadata:
  name: '${var.cluster_name}'
compute:
- hyperthreading: Enabled
  name: worker
  replicas: ${var.replicas_worker}
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: ${var.replicas_master}
networking:
  clusterNetworks:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
  machineCIDR:
platform:
  none: {}
pullSecret: '{"auths":{"none":{"auth": "none"}}}'
sshKey: ${var.public_ssh_key}
EOF
}

resource "local_file" "install_config_yaml" {
  content              = data.template_file.install_config_yaml.rendered
  filename             = "${path.root}/../install-config.yaml"
  directory_permission = "0755"
  file_permission      = "0644"
}


# data "template_file" "configure_master_node_dns" {
#   template = <<-EOF
# ---
# apiVersion: machineconfiguration.openshift.io/v1
# kind: MachineConfig
# metadata:
#   labels:
#     machineconfiguration.openshift.io/role: master
#   name: okd-configure-master-node-dns
# spec:
#   config:
#     ignition:
#       version: 3.2.0
#     storage:
#       links:
#       - path: /etc/resolv.conf
#         overwrite: true
#         target: /etc/systemd/resolved.conf.d/75-static-dns-servers.conf
#       files:
#       - contents:
#           source: data:text/plain;charset=utf-8;base64,IyBNYW5hZ2VkIHZpYSBUZXJyYWZvcm0KbmFtZXNlcnZlciAxLjEuMS4xCm5hbWVzZXJ2ZXIgMS4wLjAuMQo=
#         mode: 420
#         overwrite: true
#         path: /etc/systemd/resolved.conf.d/75-static-dns-servers.conf
# EOF
# }

# resource "local_file" "configure_master_node_dns" {
#   content              = data.template_file.configure_master_node_dns.rendered
#   filename             = "${path.root}/../okd-configure-master-node-dns.yaml"
#   directory_permission = "0755"
#   file_permission      = "0644"
# }



# data "template_file" "configure_worker_node_dns" {
#   template = <<-EOF
# ---
# apiVersion: machineconfiguration.openshift.io/v1
# kind: MachineConfig
# metadata:
#   labels:
#     machineconfiguration.openshift.io/role: worker
#   name: okd-configure-worker-node-dns
# spec:
#   config:
#     ignition:
#       version: 3.2.0
#     storage:
#       links:
#       - path: /etc/resolv.conf
#         overwrite: true
#         target: /etc/systemd/resolved.conf.d/75-static-dns-servers.conf
#       files:
#       - contents:
#           source: data:text/plain;charset=utf-8;base64,IyBNYW5hZ2VkIHZpYSBUZXJyYWZvcm0KbmFtZXNlcnZlciAxLjEuMS4xCm5hbWVzZXJ2ZXIgMS4wLjAuMQo=
#         mode: 420
#         overwrite: true
#         path: /etc/systemd/resolved.conf.d/75-static-dns-servers.conf
# EOF
# }

# resource "local_file" "configure_worker_node_dns" {
#   content              = data.template_file.configure_worker_node_dns.rendered
#   filename             = "${path.root}/../okd-configure-worker-node-dns.yaml"
#   directory_permission = "0755"
#   file_permission      = "0644"
# }
