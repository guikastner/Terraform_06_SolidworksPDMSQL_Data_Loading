# Node-RED + SQL Server + Cloudflare Tunnel (OpenTofu)

This repository provisions the stack described in `Agents.md` with OpenTofu and the Docker provider. The current spec keeps a private internal Docker network, exposes Node-RED only through a Cloudflare Tunnel, persists Node-RED and SQL Server data in named volumes, and sends daily backups to an external MinIO endpoint.

## Components
- 1 `Node-RED` container from `nodered/node-red:4.1.4-22`
- 1 `SQL Server` container from `mcr.microsoft.com/mssql/server:2022-latest`
- 1 `cloudflared` container for the Cloudflare tunnel
- 1 internal Docker network with `internal = true`
- named Docker volumes for Node-RED and SQL Server persistence
- MinIO bootstrap and backup scripts executed from OpenTofu

## What changed from the previous spec
- MongoDB was removed and replaced with SQL Server.
- Derived naming via `name_prefix` was removed; container names and the Node-RED CNAME are now explicit variables in `terraform.tfvars`.
- The old `cloudflare_tunnel = { ... }` object was replaced by flat variables:
  - `cloudflare_account_id`
  - `cloudflare_tunnel_name`
  - `cloudflare_zone_id`
  - `cloudflare_zone_name`
  - `cloudflare_api_token`
  - `cloudflare_proxied`
- Backups now target SQL Server databases plus Node-RED flow files, with the default schedule moved to midnight (`0 0 * * *`).

## Required inputs
Fill `terraform.tfvars` with the real values. Use `terraform.tfvars.example` as the starting point.

Main variables:
- `node_red_container_name`
- `node_red_cname`
- `node_red_admin_username`
- `node_red_admin_password`
- `sqlserver_container_name`
- `sqlserver_sa_password`
- `cloudflared_container_name`
- `minio_access_key`
- `minio_secret_key`
- `minio_bucket_name`
- `cloudflare_api_token`
- `cloudflare_account_id`
- `cloudflare_zone_id`
- `cloudflare_zone_name`
- `cloudflare_tunnel_name`

## Node-RED behavior
- Node-RED keeps outbound internet access through Docker `bridge` so palette modules can be installed.
- `settings.js` is rendered from `templates/node-red-settings.js.tmpl` and mounted read-only into `/data/settings.js`.
- `terraform.tfvars` must contain the plain Node-RED admin password, not its bcrypt hash.
- The bcrypt hash is generated during deploy/runtime by the Node-RED settings logic through `bcryptjs`.
- Default Node-RED admin credentials follow `Agents.md`:
  - user: `admin`
  - password: `0102030405!`

## Cloudflare tunnel
The tunnel is still created by OpenTofu. The implementation keeps:
- `cloudflare_zero_trust_tunnel_cloudflared`
- `cloudflare_zero_trust_tunnel_cloudflared_config`
- a `cloudflare_record` CNAME pointing to `${tunnel_id}.cfargotunnel.com`
- the `cloudflared` container mounted with generated config and credentials

All Cloudflare inputs now come directly from `terraform.tfvars`. Runtime tunnel files are rendered under `build/cloudflare/`.

## Backups
OpenTofu generates `build/backup/backup_runner.sh`, installs a cron entry on the host, and executes `scripts/backup_run.sh`.

Each run:
- creates `.bak` backups for every non-system SQL Server database
- archives Node-RED flow files from `/data`
- uploads artifacts to MinIO under:
  - `backup/sqlserver`
  - `backup/node-red`

## Restore on deploy
- If `sqlserver_restore_enabled = true`, `tofu apply` looks for `.bak` files in `database/` and `databases/`.
- Each matching file is copied into the SQL Server container and restored automatically.
- The restore resource re-runs when:
  - a `.bak` file changes,
  - a new `.bak` file is added or removed,
  - the SQL Server container is recreated.
- The restore always uses the original database name stored inside the `.bak` metadata (`RESTORE HEADERONLY`), not the backup filename.

## Files
- `variables.tf`: new input schema
- `containers.tf`: Node-RED and SQL Server containers
- `cloudflare.tf` / `cloudflare_dns.tf`: tunnel, agent, and DNS resources
- `scripts/minio_setup.sh`: bucket and folder bootstrap
- `scripts/backup_run.sh`: SQL Server and Node-RED backup workflow
- `templates/node-red-settings.js.tmpl`: generated Node-RED settings
- `templates/cloudflared-config.yml.tmpl`: generated cloudflared config
- `terraform.tfvars.example`: single source of example input values

## Usage
```bash
tofu init
tofu fmt -recursive
tofu plan
tofu apply
```

## Notes
- No container publishes host ports.
- Node-RED and cloudflared use the internal network plus Docker `bridge` for outbound internet access.
- SQL Server stays only on the internal network.
- `terraform.tfvars` remains ignored by Git.
