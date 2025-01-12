data "template_file" "ignition_config" {
  template = file("${path.module}/templates/ignition.ign")
  vars = {
    hostname         = "${format("${var.name}%02d", count.index + 1)}.${var.cluster_url}"
    hostname_b64     = base64encode("${format("${var.name}%02d", count.index + 1)}.${var.cluster_url}")
    resolvconf_b64   = base64encode(file("${path.module}/templates/resolv.conf"))
    ignition_url     = var.ignition_url
    ignition_version = var.ignition_version
    ignition_cacert  = var.ignition_cacert
  }
  count = var.instance_count
}

resource "local_file" "ignition_config" {
  content  = data.template_file.ignition_config[count.index].rendered
  filename = "${path.root}/../ignition/${format("${var.name}%02d", count.index + 1)}.${var.cluster_url}.ign"
  count    = var.instance_count
}
