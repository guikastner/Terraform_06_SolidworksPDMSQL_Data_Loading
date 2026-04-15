# Node-RED + SQL Server + WebDB (Docker Compose)

This branch is the Docker Compose variation of the project. It does not use OpenTofu, Cloudflare, MinIO, or any provisioned backup routine.

## Overview
The stack provides:
- `node-red` based on `nodered/node-red:4.1.4-22`
- `sqlserver` based on `mcr.microsoft.com/mssql/server:2022-latest`
- `webdb` based on `webdb/app:latest`
- one internal Docker network
- named volumes for Node-RED and SQL Server persistence

The intent of this variation is to keep the project self-contained and runnable with Docker Compose only.

## Architecture
- `sqlserver` runs on the internal Docker network only.
- `webdb` runs on the internal Docker network and is published locally on `127.0.0.1:${WEBDB_HOST_PORT}`.
- `node_red` runs on the internal Docker network and is published locally on `127.0.0.1:${NODE_RED_HOST_PORT}`.
- `node_red_init` is a one-shot initialization service that:
  - creates the Node-RED `settings.js`
  - hashes the Node-RED admin password
  - installs extra Node-RED modules into the persistent volume
- `sqlserver_restore` is a one-shot initialization service that restores `.bak` files automatically when enabled

## Prerequisites
- Docker Engine installed and working
- Docker Compose v2 available through `docker compose`
- enough disk space for:
  - SQL Server image
  - WebDB image
  - Node-RED image
  - Node-RED and SQL Server named volumes
  

## Important architecture note
The official SQL Server Linux container image is supported on `x86_64`.

On `arm64`, this Compose variation uses:
- `SQLSERVER_PLATFORM=linux/amd64`

That means it depends on emulation support in Docker. This may be slow, unstable, or fail entirely depending on the host. It is not equivalent to native `arm64` support.

## Files
- [docker-compose.yml](/DATA/AppData/git/Terraform_06_SolidworksPDMSQL_Data_Loading/docker-compose.yml): main stack definition
- [.env.example](/DATA/AppData/git/Terraform_06_SolidworksPDMSQL_Data_Loading/.env.example): example configuration values
- [build/](/DATA/AppData/git/Terraform_06_SolidworksPDMSQL_Data_Loading/build): generated runtime artifacts such as `build/node-red/settings.js`
- [databases/](/DATA/AppData/git/Terraform_06_SolidworksPDMSQL_Data_Loading/databases): local `.bak` files kept with this variation when needed for manual restore

## Configuration
1. Copy `.env.example` to `.env`.
2. Adjust at least these variables:
   - `NODE_RED_CONTAINER_NAME`
   - `NODE_RED_HOST_PORT`
   - `NODE_RED_ADMIN_USERNAME`
   - `NODE_RED_ADMIN_PASSWORD`
   - `NODE_RED_CREDENTIAL_SECRET`
   - `SQLSERVER_CONTAINER_NAME`
   - `SQLSERVER_SA_PASSWORD`
   - `WEBDB_CONTAINER_NAME`
   - `WEBDB_HOST_PORT`
3. Review these image and platform variables:
   - `NODE_RED_IMAGE`
   - `SQLSERVER_IMAGE`
   - `SQLSERVER_PLATFORM`
   - `WEBDB_IMAGE`

## Default environment variables
The example file currently defines:
- timezone: `America/Sao_Paulo`
- Node-RED host port: `1880`
- WebDB host port: `22071`
- SQL Server edition: `Developer`
- SQL Server platform: `linux/amd64`

## Starting the stack
Bring everything up:

```bash
docker compose up -d
```

The expected startup order is:
1. `sqlserver`
2. `sqlserver_restore`
3. `webdb`
4. `node_red_init`
5. `node_red`

Check status:

```bash
docker compose ps
```

Inspect logs:

```bash
docker compose logs -f
```

## Stopping the stack
Stop the services:

```bash
docker compose down
```

Stop and remove named volumes too:

```bash
docker compose down -v
```

Use `-v` only if you explicitly want to delete Node-RED and SQL Server persistent data.

## Access
- Node-RED: `http://127.0.0.1:${NODE_RED_HOST_PORT}`
- WebDB: `http://127.0.0.1:${WEBDB_HOST_PORT}`

SQL Server is not published to the host in this variation.

## Persistence
The stack uses named volumes:
- `node_red_data`
- `sqlserver_data`

These volumes survive container recreation unless explicitly removed.

## Node-RED behavior
- The admin password is stored as plain text in `.env`.
- The bcrypt hash is generated during startup by the `node_red_init` one-shot service defined directly in `docker-compose.yml`.
- Node-RED settings are rendered into `build/node-red/settings.js`.
- Extra modules are installed into the named volume before the main Node-RED container starts.
- The generated settings include:
  - admin authentication
  - credential secret
  - SQL Server connection metadata in `functionGlobalContext`
  - palette editing enabled

## Automatic restore of `.bak`
This variation performs restore automatically through the `sqlserver_restore` one-shot service.

If `SQLSERVER_RESTORE_ENABLED=true`, the stack looks for `.bak` files in:
- `database/`
- `databases/`

For each backup file found:
- the original database name is read from `RESTORE HEADERONLY`
- the logical files are read from `RESTORE FILELISTONLY`
- the restore is executed with `WITH MOVE` and `WITH REPLACE`

The backup filename is not used as the database name.

If no `.bak` files are found, `sqlserver_restore` exits successfully and the rest of the stack continues normally.

To disable automatic restore for a given run:

```env
SQLSERVER_RESTORE_ENABLED=false
```

## Security notes
- [`.env`](/DATA/AppData/git/Terraform_06_SolidworksPDMSQL_Data_Loading/.env) is ignored by Git, but it still contains secrets in plain text.
- `build/` is ignored by Git, but generated files may include sensitive material such as:
  - `credentialSecret`
  - hashed Node-RED password
- Secrets passed as container environment variables are visible to users who have access to the Docker daemon.
- Node-RED and WebDB are bound to `127.0.0.1`, not `0.0.0.0`, which reduces exposure on the host network.

## Troubleshooting
### SQL Server container keeps restarting
If you see errors like `exec format error`, the host likely cannot run the SQL Server image correctly under the configured platform.

Check:

```bash
docker compose logs sqlserver
```

### Restore service fails
Inspect:

```bash
docker compose logs sqlserver_restore
```

Common reasons:
- no `sqlcmd` binary available in the image
- unsupported SQL Server runtime on the current host architecture
- invalid or incompatible `.bak`
- logical file names in the backup cannot be mapped automatically

### Node-RED does not start
Inspect the init container first:

```bash
docker compose logs node_red_init
```

Then inspect the main service:

```bash
docker compose logs node_red
```

### WebDB does not come up
Inspect:

```bash
docker compose logs webdb
```

### Validate the resolved Compose configuration

```bash
docker compose --env-file .env.example config
```

## Scope of this variation
- No Cloudflare resources
- No MinIO resources
- No backup provisioning
- No OpenTofu resources
- No repository shell scripts
