terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.38.2"
    }
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.2.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "4.54.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
  }
  required_version = ">= 0.14"
}
