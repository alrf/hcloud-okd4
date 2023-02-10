variable "api_token" {
  type        = string
  description = "Hetzner DNS token"
}

variable "records" {
  type = map(string)
}

variable "type" {
  type = string
}

variable "zone_id" {
  type = string
}

locals {
  api_url = "https://dns.hetzner.com/api/v1/records"
}
