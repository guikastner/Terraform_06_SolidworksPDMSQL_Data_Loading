resource "null_resource" "sqlserver_restore" {
  count = var.sqlserver_restore_enabled && length(local.sqlserver_restore_files) > 0 ? 1 : 0

  triggers = {
    restore_files = sha256(join(",", [
      for bak_file in local.sqlserver_restore_relative_files :
      "${bak_file}:${filesha256("${path.module}/${bak_file}")}"
    ]))
    container_name = local.sqlserver_instance.name
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/restore_databases.sh"
    environment = {
      SQLSERVER_CONTAINER_NAME = local.sqlserver_instance.name
      SQLSERVER_SA_USERNAME    = var.sqlserver_sa_username
      SQLSERVER_SA_PASSWORD    = var.sqlserver_sa_password
      SQLSERVER_RESTORE_FILES  = join(":", local.sqlserver_restore_files)
    }
  }

  depends_on = [docker_container.sqlserver]

  lifecycle {
    replace_triggered_by = [docker_container.sqlserver]
  }
}
