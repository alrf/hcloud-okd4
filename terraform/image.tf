data "hcloud_image" "image" {
  with_selector = "os=${var.image},location=${var.location},image_type=generic"
  with_status   = ["available"]
  most_recent   = true
}
