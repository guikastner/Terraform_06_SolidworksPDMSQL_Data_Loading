resource "docker_volume" "node_red_data" {
  name = "${var.node_red_container_name}-data"
}

resource "docker_volume" "sqlserver_data" {
  name = "${var.sqlserver_container_name}-data"
}

resource "null_resource" "backup_dirs" {
  count = var.backup_enabled ? 1 : 0

  provisioner "local-exec" {
    command = "mkdir -p ${local.backup_local_dir} ${local.backup_generated_dir}"
  }
}
