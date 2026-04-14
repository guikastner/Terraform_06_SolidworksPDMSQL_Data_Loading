resource "null_resource" "minio_bucket_setup" {
  count = var.minio_bucket_name != "" ? 1 : 0

  triggers = {
    endpoint = var.minio_endpoint
    bucket   = var.minio_bucket_name
    folders  = sha256(join(",", var.minio_bucket_folders))
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/minio_setup.sh"
    environment = {
      MINIO_ENDPOINT       = var.minio_endpoint
      MINIO_ACCESS_KEY     = var.minio_access_key
      MINIO_SECRET_KEY     = var.minio_secret_key
      MINIO_BUCKET_NAME    = var.minio_bucket_name
      MINIO_BUCKET_FOLDERS = join(",", var.minio_bucket_folders)
    }
  }
}
