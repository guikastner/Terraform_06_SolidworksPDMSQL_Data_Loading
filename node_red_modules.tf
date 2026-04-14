resource "null_resource" "node_red_modules" {
  provisioner "local-exec" {
    command = <<-EOT
      docker run --rm --entrypoint npm -v ${docker_volume.node_red_data.name}:/data ${var.node_red_image} \
        install --no-progress --no-audit --unsafe-perm --prefix /data ${join(" ", var.node_red_extra_modules)}
    EOT
  }

  triggers = {
    modules     = join(",", var.node_red_extra_modules)
    image       = var.node_red_image
    volume_name = docker_volume.node_red_data.name
  }

  depends_on = [docker_volume.node_red_data]
}
