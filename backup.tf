resource "local_sensitive_file" "backup_runner" {
  count           = var.backup_enabled ? 1 : 0
  filename        = local.backup_runner_path
  file_permission = "0700"
  content         = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail
    export MINIO_ENDPOINT='${replace(var.minio_endpoint, "'", "'\"'\"'")}'
    export MINIO_ACCESS_KEY='${replace(var.minio_access_key, "'", "'\"'\"'")}'
    export MINIO_SECRET_KEY='${replace(var.minio_secret_key, "'", "'\"'\"'")}'
    export MINIO_BUCKET_NAME='${replace(var.minio_bucket_name, "'", "'\"'\"'")}'
    export MINIO_SQLSERVER_PREFIX='${replace(var.backup_sqlserver_prefix, "'", "'\"'\"'")}'
    export MINIO_NODE_RED_PREFIX='${replace(var.backup_node_red_prefix, "'", "'\"'\"'")}'
    export SQLSERVER_CONTAINER_NAME='${replace(local.sqlserver_instance.name, "'", "'\"'\"'")}'
    export SQLSERVER_SA_USERNAME='${replace(var.sqlserver_sa_username, "'", "'\"'\"'")}'
    export SQLSERVER_SA_PASSWORD='${replace(var.sqlserver_sa_password, "'", "'\"'\"'")}'
    export NODE_RED_CONTAINER_NAME='${replace(local.node_red_instance.name, "'", "'\"'\"'")}'
    export BACKUP_LOCAL_DIR='${replace(local.backup_local_dir, "'", "'\"'\"'")}'
    export BACKUP_RETENTION_DAYS='${var.backup_retention_days}'
    exec '${replace(local.backup_script_path, "'", "'\"'\"'")}'
  EOT

  depends_on = [null_resource.backup_dirs]
}

resource "null_resource" "backup_cron_install" {
  count = var.backup_enabled ? 1 : 0

  triggers = {
    schedule    = var.backup_cron_schedule
    runner_path = local.backup_runner_path
    log_file    = local.backup_log_file
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      CRON_TAG="# node_red_sqlserver_backup_job"
      CRON_CMD="${var.backup_cron_schedule} ${local.backup_runner_path} >> ${local.backup_log_file} 2>&1 $CRON_TAG"
      { crontab -l 2>/dev/null | grep -F -v "$CRON_TAG" || true; echo "$CRON_CMD"; } | crontab -
    EOT
  }

  depends_on = [
    local_sensitive_file.backup_runner,
    null_resource.minio_bucket_setup,
  ]
}

resource "null_resource" "backup_cron_remove" {
  count = var.backup_enabled ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      CRON_TAG="# node_red_sqlserver_backup_job"
      crontab -l 2>/dev/null | grep -F -v "$CRON_TAG" | crontab - || true
    EOT
  }
}
