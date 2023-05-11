data "hcloud_image" "image" {
  with_selector = "os=${var.image},location=${var.location},image_type=generic"
  with_status   = ["available"]
  most_recent   = true
}

data "hcloud_image" "debian" {
  name              = "debian-11"
  with_architecture = "x86"
  most_recent       = true
}
