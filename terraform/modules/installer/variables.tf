variable "replicas_master" {
  type = number
}

variable "replicas_worker" {
  type = number
}

variable "domain" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "postinstall" {
  type = bool
}

variable "hcloud_token" {
  type = string
}

variable "kubeconfig" {
  type    = string
  default = "/workspace/ignition/auth/kubeconfig"
}

variable "kubeadmin_password" {
  type    = string
  default = "/workspace/ignition/auth/kubeadmin-password"
}

variable "ssh_key" {
  type        = string
  description = "It will be created automatically"
  default     = "/root/.ssh/tf_okd4_dev_hetzner"
}
