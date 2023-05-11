variable "records" {
  type = map(string)
}

variable "type" {
  type = string
}

variable "force_update" {
  type    = string
  default = ""
}
