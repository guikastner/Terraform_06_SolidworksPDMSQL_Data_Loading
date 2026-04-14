locals {
  node_red_instance = {
    name     = var.node_red_container_name
    hostname = var.cloudflare_zone_name != "" ? "${var.node_red_cname}.${var.cloudflare_zone_name}" : var.node_red_cname
  }

  sqlserver_instance = {
    name = var.sqlserver_container_name
  }

  webdb_instance = {
    name     = var.webdb_container_name
    hostname = var.cloudflare_zone_name != "" ? "${var.webdb_cname}.${var.cloudflare_zone_name}" : var.webdb_cname
  }

  cloudflared_instance = {
    name = var.cloudflared_container_name
  }

  data_root = "/DATA/AppData"

  sqlserver_restore_relative_files = distinct(concat(
    tolist(fileset(path.module, "database/*.bak")),
    tolist(fileset(path.module, "databases/*.bak")),
  ))
  sqlserver_restore_files = [for bak_file in local.sqlserver_restore_relative_files : abspath("${path.module}/${bak_file}")]

  node_red_generated_dir = abspath("${path.module}/build/node-red")
  node_red_settings_path = abspath("${local.node_red_generated_dir}/settings.js")

  cloudflare_generated_dir    = abspath("${path.module}/build/cloudflare")
  cloudflare_config_path      = abspath("${local.cloudflare_generated_dir}/config.yml")
  cloudflare_credentials_path = abspath("${local.cloudflare_generated_dir}/cloudflared-credentials.json")

  backup_local_dir     = abspath("${local.data_root}/${var.node_red_container_name}-backups")
  backup_log_file      = abspath("${local.backup_local_dir}/backup.log")
  backup_script_path   = abspath("${path.module}/scripts/backup_run.sh")
  backup_generated_dir = abspath("${path.module}/build/backup")
  backup_runner_path   = abspath("${local.backup_generated_dir}/backup_runner.sh")
}
