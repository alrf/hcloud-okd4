variable "replicas_master" {
  type = number
  #default = 1
  default     = 3
  description = "Count of master replicas"
}

variable "replicas_worker" {
  type = number
  #default = 0
  #default = 3
  default     = 6
  description = "Count of worker replicas"
}

variable "bootstrap" {
  type        = bool
  default     = false
  description = "Whether to deploy a bootstrap instance"
}

variable "domain" {
  type        = string
  description = "Set your DNS domain here"
}

variable "cluster_name" {
  type        = string
  description = "Cluster name (it will be <cluster_name>.<domain>)"
}

variable "ip_loadbalancer_api" {
  description = "IP of an external loadbalancer for api (optional)"
  default     = null
}

variable "ip_loadbalancer_api_int" {
  description = "IP of an external loadbalancer for api-int (optional)"
  default     = null
}

variable "ip_loadbalancer_apps" {
  description = "IP of an external loadbalancer for apps (optional)"
  default     = null
}

variable "network_cidr" {
  type        = string
  description = "CIDR for the network"
  default     = "192.168.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR for the subnet"
  default     = "192.168.254.0/24"
}

variable "lb_subnet_cidr" {
  type        = string
  description = "CIDR for the loadbalancer subnet"
  default     = "192.168.253.0/24"
}

variable "location" {
  type        = string
  description = "The location name to create the server in. nbg1, fsn1 or hel1"
  default     = "fsn1"
}

variable "image" {
  type        = string
  description = "Image selector (either fcos or rhcos)"
  default     = "fcos"
}

variable "dns_api_token" {
  type = string
}

variable "dns_zone_id" {
  type        = string
  description = "Hetzner DNS zone_id"
}

variable "generate_okd_configs" {
  type        = bool
  default     = false
  description = "Whether to generate OKD configs"
}

variable "public_ssh_key" {
  type        = string
  description = "Public ssh key using on Hetzner nodes"
}
