variable "docker_host" {
  description = "Docker host socket URL. Keep default for local Docker engine."
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "timezone" {
  description = "Timezone applied to containers that support TZ."
  type        = string
  default     = "UTC"
}

variable "node_red_container_name" {
  description = "Container name used for the Node-RED service."
  type        = string
  default     = "node-red1"
}

variable "node_red_cname" {
  description = "Cloudflare CNAME label that should route to the Node-RED service."
  type        = string
  default     = "node-red1"
}

variable "node_red_image" {
  description = "Container image for Node-RED."
  type        = string
  default     = "nodered/node-red:4.1.4-22"
}

variable "sqlserver_container_name" {
  description = "Container name used for the SQL Server service."
  type        = string
  default     = "sqlserver1"
}

variable "sqlserver_image" {
  description = "Container image for SQL Server."
  type        = string
  default     = "mcr.microsoft.com/mssql/server:2022-latest"
}

variable "sqlserver_sa_username" {
  description = "Administrator login for SQL Server. The container image expects `sa`."
  type        = string
  default     = "sa"
}

variable "sqlserver_sa_password" {
  description = "Administrator password for SQL Server."
  type        = string
  sensitive   = true
}

variable "sqlserver_edition" {
  description = "SQL Server edition/product ID accepted by the container image."
  type        = string
  default     = "Developer"
}

variable "cloudflared_container_name" {
  description = "Container name used for the cloudflared tunnel agent."
  type        = string
  default     = "cloudflared1"
}

variable "cloudflared_image" {
  description = "Container image for Cloudflare Tunnel agent."
  type        = string
  default     = "cloudflare/cloudflared:latest"
}

variable "node_red_admin_username" {
  description = "Admin username for the Node-RED editor."
  type        = string
  default     = "admin"
}

variable "node_red_admin_password" {
  description = "Plain-text admin password for the Node-RED editor. The bcrypt hash is generated during deploy."
  type        = string
  default     = "0102030405!"
  sensitive   = true
}

variable "node_red_credential_secret" {
  description = "Secret used by Node-RED to encrypt flow credentials."
  type        = string
  default     = "credential-secret"
  sensitive   = true
}

variable "node_red_extra_modules" {
  description = "List of npm packages (names or URLs) to install into the Node-RED data volume."
  type        = list(string)
  default = [
    "https://btcc.s3.dualstack.eu-west-1.amazonaws.com/widget-lab/npm/node-red-contrib-3dxinterfaces/dist/widget-lab-node-red-contrib-3dxinterfaces-6.5.1.tgz",
    "node-red-contrib-mssql-plus",
    "node-red-contrib-xlsx-to-json",
    "node-red-contrib-minio-all",
  ]
}

variable "minio_endpoint" {
  description = "MinIO/S3 endpoint URL used for bucket provisioning."
  type        = string
  default     = "https://minio2.kastner.com.br"
}

variable "minio_access_key" {
  description = "MinIO access key (user)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "minio_secret_key" {
  description = "MinIO secret key (password)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "minio_bucket_name" {
  description = "Bucket name to create in MinIO. Leave empty to skip provisioning."
  type        = string
  default     = ""
}

variable "minio_bucket_folders" {
  description = "List of first-level folders to ensure inside the MinIO bucket."
  type        = list(string)
  default     = ["backup"]
}

variable "backup_enabled" {
  description = "If true, configures the scheduled backup workflow."
  type        = bool
  default     = true
}

variable "backup_cron_schedule" {
  description = "Cron schedule used to run the backup on the host."
  type        = string
  default     = "0 0 * * *"
}

variable "backup_retention_days" {
  description = "Number of days to keep local backup artifacts before cleanup."
  type        = number
  default     = 14
}

variable "backup_sqlserver_prefix" {
  description = "MinIO folder/prefix used for SQL Server backups."
  type        = string
  default     = "backup/sqlserver"
}

variable "backup_node_red_prefix" {
  description = "MinIO folder/prefix used for Node-RED backup files."
  type        = string
  default     = "backup/node-red"
}

variable "cloudflare_api_token" {
  description = "API token with permissions to manage tunnels and DNS records."
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID where the tunnel is created."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Zone ID in Cloudflare where CNAMEs are created."
  type        = string
}

variable "cloudflare_zone_name" {
  description = "Zone name used to build the Node-RED FQDN."
  type        = string
  default     = ""
}

variable "cloudflare_origin_address" {
  description = "Origin address kept in settings/example files for reference."
  type        = string
  default     = ""
}

variable "cloudflare_proxied" {
  description = "Whether created DNS records should be proxied by Cloudflare."
  type        = bool
  default     = true
}

variable "cloudflare_tunnel_name" {
  description = "Name of the Cloudflare tunnel created by OpenTofu."
  type        = string
}
