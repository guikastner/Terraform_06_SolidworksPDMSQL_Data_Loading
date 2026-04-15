# Environment Variable Reference

This document describes the environment variables used by the Docker Compose variation of this repository.

It is intentionally more detailed than [README.md](/e:/Git/Terraform_06_SolidworksPDMSQL_Data_Loading/README.md) and focuses on:
- which variables are actually consumed by `docker-compose.yml`
- which variables affect only first-time initialization or restore workflows
- which variables are currently documented or present in `.env`, but are not wired into the active Compose flow
- operational and security implications of changing each variable

## How Environment Resolution Works

The stack relies on Docker Compose variable substitution. In practice:
- `docker compose` reads values from `.env` in the project root by default
- those values are expanded into `docker-compose.yml`
- some variables are then passed into containers as container environment variables
- other variables are used only by Compose itself, such as image names, ports, volume names, and container names

This means there are two distinct classes of variables:
- Compose-time variables: used before the container starts
- Runtime container variables: available inside the running container

Some variables are both.

## Added MCP Service

This repository now includes an optional MSSQL MCP service based on `mcprunner/mssqlmcp`.

Purpose:
- expose a SQL Server MCP endpoint over HTTP for MCP-capable clients such as VS Code

What this integration does:
- adds a long-running `mssql_mcp` service to `docker-compose.yml`
- persists MCP server state under Docker volumes
- exposes the MCP endpoint on `127.0.0.1:${MSSQL_MCP_HOST_PORT}`

What this integration does not do automatically:
- provision SQL connection definitions inside the MCP server
- generate editor-specific MCP config files
- inject SQL credentials into the MCP server's internal connection store

Those connection definitions are managed by the MCP server itself after startup.

## Operational Notes

### Persistence-sensitive variables

Some variables do not behave like normal application settings after the first startup.

- `SQLSERVER_SA_PASSWORD`
  Changes the SQL Server bootstrap password only when the SQL Server data volume is initialized from scratch.
  If the `sqlserver_data` volume already exists, changing the value in `.env` does not automatically change the actual `sa` password inside the database engine.

- `SQLSERVER_CONTAINER_NAME`
  Also changes the SQL Server volume name because the Compose file defines the volume as `${SQLSERVER_CONTAINER_NAME}-data`.
  Changing it effectively points the stack to a different persisted SQL Server data volume.

- `NODE_RED_CONTAINER_NAME`
  Also changes the Node-RED data volume name because the Compose file defines the volume as `${NODE_RED_CONTAINER_NAME}-data`.
  Changing it effectively points the stack to a different Node-RED persisted state.

### Restore behavior

The `sqlserver_restore` service is a one-shot init service. It:
- waits for SQL Server query readiness
- scans `database/` and `databases/` for `.bak` files
- reads the original database name from `RESTORE HEADERONLY`
- reads logical file names from `RESTORE FILELISTONLY`
- runs `RESTORE DATABASE ... WITH MOVE, REPLACE, RECOVERY`

Important implications:
- if `SQLSERVER_RESTORE_ENABLED=false`, no restore is attempted
- if no `.bak` files are present, the service exits successfully without restoring anything
- on container recreation, restore can run again against the same persistent SQL Server volume
- because `WITH REPLACE` is used, a matching target database may be overwritten

### Variables currently present but not consumed by the active Compose flow

The repository currently contains variables and templates related to a richer Node-RED setup than the active Compose flow uses today.

These variables may appear in `.env`, in `README.md`, or in templates, but are not directly wired by the current `docker-compose.yml`:
- `NODE_RED_ADMIN_USERNAME`
- `NODE_RED_ADMIN_PASSWORD`
- `NODE_RED_CREDENTIAL_SECRET`
- `NODE_RED_EXTRA_MODULES`

Related files:
- [templates/node-red-settings.js.tmpl](/e:/Git/Terraform_06_SolidworksPDMSQL_Data_Loading/templates/node-red-settings.js.tmpl)

At the moment:
- the active `node_red` service only receives `TZ`
- package installation in `node_red_init` is hard-coded in `docker-compose.yml`
- the generated `settings.js` template flow described earlier in the repository history is not the active path used by the current Compose file

If those variables are expected to control runtime behavior, the Compose file would need additional wiring.

## Variable Reference

### `TZ`

Purpose:
- sets the container timezone for services that receive it

Consumed by:
- `sqlserver`
- `node_red`

Current example/default:

```env
TZ=America/Sao_Paulo
```

Impact:
- affects timestamps and local-time behavior inside containers
- does not affect host time

When to change:
- when the deployment should follow another local timezone

Risk:
- low

### `NODE_RED_CONTAINER_NAME`

Purpose:
- defines the container name for the main Node-RED service
- defines the persisted Node-RED volume name suffix

Consumed by:
- `node_red.container_name`
- `node_red_init.container_name`
- `volumes.node_red_data.name`

Current example/default:

```env
NODE_RED_CONTAINER_NAME=noderedsqlserver1
```

Impact:
- renames containers
- changes the backing Docker volume name from the Compose perspective

When to change:
- when multiple stacks must coexist on the same Docker host

Risk:
- medium

Important note:
- changing this value usually results in a different Node-RED data volume being used
- that can make it look like flows or installed nodes were lost, when in reality the stack is pointing to a different volume

### `NODE_RED_IMAGE`

Purpose:
- selects the Node-RED container image

Consumed by:
- `node_red.image`
- `node_red_init.image`

Current example/default:

```env
NODE_RED_IMAGE=nodered/node-red:4.1.4-22
```

Impact:
- changes Node.js and Node-RED runtime versions
- can affect compatibility of installed palettes

When to change:
- when upgrading or pinning Node-RED

Risk:
- medium to high

Important note:
- custom nodes may depend on a minimum Node.js version
- image changes should be validated together with installed palettes

### `NODE_RED_HOST_PORT`

Purpose:
- publishes Node-RED on the host

Consumed by:
- `node_red.ports`

Current example/default:

```env
NODE_RED_HOST_PORT=1880
```

Impact:
- changes the host port for the editor/UI

When to change:
- when `1880` is already occupied
- when running multiple stacks in parallel

Risk:
- low

### `NODE_RED_ADMIN_USERNAME`

Purpose:
- intended to define the Node-RED admin username

Consumed by:
- not consumed by the current active `docker-compose.yml`

Current local `.env` example:

```env
NODE_RED_ADMIN_USERNAME=admin
```

Impact:
- none in the active Compose flow unless additional wiring is restored

Risk:
- low, but misleading if users assume it is active

### `NODE_RED_ADMIN_PASSWORD`

Purpose:
- intended to define the Node-RED admin password

Consumed by:
- not consumed by the current active `docker-compose.yml`

Current local `.env` example:

```env
NODE_RED_ADMIN_PASSWORD=0102030405!
```

Impact:
- none in the active Compose flow unless additional wiring is restored

Risk:
- high if left in `.env` unnecessarily because it is still a secret in plain text

### `NODE_RED_CREDENTIAL_SECRET`

Purpose:
- intended to define the Node-RED `credentialSecret`

Consumed by:
- not consumed by the current active `docker-compose.yml`

Current local `.env` example:

```env
NODE_RED_CREDENTIAL_SECRET=set-your-own-secret
```

Impact:
- none in the active Compose flow unless additional wiring is restored

Risk:
- medium, because operators may think credentials are protected by this value when they are not currently wiring it

### `NODE_RED_EXTRA_MODULES`

Purpose:
- intended to declare extra Node-RED modules to install

Consumed by:
- not consumed dynamically by the current active `docker-compose.yml`

Current local `.env` example:

```env
NODE_RED_EXTRA_MODULES=https://btcc.s3.dualstack.eu-west-1.amazonaws.com/widget-lab/npm/node-red-contrib-3dxinterfaces/dist/widget-lab-node-red-contrib-3dxinterfaces-6.5.3.tgz,node-red-contrib-mssql-plus,node-red-contrib-xlsx-to-json,node-red-contrib-minio-all
```

Current real behavior:
- extra modules are currently installed by hard-coded `npm install` commands in `node_red_init`
- this variable is therefore informational only unless the Compose file is updated to consume it

Risk:
- medium, because it suggests configurability that does not currently exist

### `SQLSERVER_CONTAINER_NAME`

Purpose:
- defines the SQL Server container name
- defines the persisted SQL Server volume name suffix
- defines the host name used by `sqlserver_restore`

Consumed by:
- `sqlserver.container_name`
- `sqlserver_restore.container_name`
- `sqlserver_restore.environment.SQLSERVER_HOST`
- `volumes.sqlserver_data.name`

Current example/default:

```env
SQLSERVER_CONTAINER_NAME=sqlserver1
```

Impact:
- renames the SQL Server container
- changes which SQL Server data volume is used
- changes the restore target host name on the Docker network

Risk:
- high if changed on an existing stack without understanding volume implications

### `SQLSERVER_IMAGE`

Purpose:
- selects the SQL Server image

Consumed by:
- `sqlserver.image`
- `sqlserver_restore.image`

Current example/default:

```env
SQLSERVER_IMAGE=mcr.microsoft.com/mssql/server:2022-latest
```

Impact:
- changes SQL Server engine version
- can affect restore compatibility, startup time, and architecture support

Risk:
- medium to high

### `SQLSERVER_PLATFORM`

Purpose:
- forces the platform used by Docker for SQL Server containers

Consumed by:
- `sqlserver.platform`
- `sqlserver_restore.platform`

Current example/default:

```env
SQLSERVER_PLATFORM=linux/amd64
```

Impact:
- required on hosts where SQL Server must run under emulation

Risk:
- medium

Important note:
- especially relevant on `arm64` hosts
- incorrect values can prevent startup entirely

### `SQLSERVER_SA_USERNAME`

Purpose:
- defines the SQL login used by the restore container to connect to SQL Server

Consumed by:
- `sqlserver_restore.environment.SQLSERVER_SA_USERNAME`

Current example/default:

```env
SQLSERVER_SA_USERNAME=sa
```

Impact:
- restore service login identity

Risk:
- low if left as `sa`

Important note:
- the main SQL Server container itself does not use this variable for initialization; it only uses the password

### `SQLSERVER_SA_PASSWORD`

Purpose:
- sets the bootstrap `sa` password for SQL Server
- also provides the password used by `sqlserver_restore`

Consumed by:
- `sqlserver.environment.MSSQL_SA_PASSWORD`
- `sqlserver_restore.environment.SQLSERVER_SA_PASSWORD`

Current example/default:

```env
SQLSERVER_SA_PASSWORD=change-me
```

Operational behavior:
- on a fresh SQL Server volume, it sets the initial `sa` password
- on an existing SQL Server volume, it does not automatically rotate the actual database login password
- the restore service still tries to use the value present in `.env`

Risk:
- high

Important notes:
- must satisfy SQL Server password complexity requirements on first initialization
- if the persisted volume was initialized with a different password, restore and application connectivity may fail with login errors

### `SQLSERVER_EDITION`

Purpose:
- selects the SQL Server edition

Consumed by:
- `sqlserver.environment.MSSQL_PID`

Current example/default:

```env
SQLSERVER_EDITION=Developer
```

Impact:
- licensing and feature availability

Risk:
- medium

### `SQLSERVER_RESTORE_ENABLED`

Purpose:
- enables or disables automatic backup restore

Consumed by:
- `sqlserver_restore.environment.SQLSERVER_RESTORE_ENABLED`

Current example/default:

```env
SQLSERVER_RESTORE_ENABLED=true
```

Impact:
- when `true`, `sqlserver_restore` scans for `.bak` files and attempts restore
- when `false`, `sqlserver_restore` exits immediately and the rest of the stack continues

Risk:
- medium

Important note:
- useful when the SQL Server volume already contains the desired database state and re-restore is not wanted

### `DBGATE_CONTAINER_NAME`

Purpose:
- defines the DbGate container name
- defines the persisted DbGate volume name suffix

Consumed by:
- `dbgate.container_name`
- `volumes.dbgate_data.name`

Current example/default:

```env
DBGATE_CONTAINER_NAME=dbgate1
```

Impact:
- renames the container
- changes which DbGate state volume is used

Risk:
- medium

### `DBGATE_IMAGE`

Purpose:
- selects the DbGate image

Consumed by:
- `dbgate.image`

Current example/default:

```env
DBGATE_IMAGE=dbgate/dbgate:latest
```

Impact:
- changes DbGate runtime version

Risk:
- medium if relying on `latest`

### `DBGATE_HOST_PORT`

Purpose:
- publishes DbGate on the host

Consumed by:
- `dbgate.ports`

Current example/default:

```env
DBGATE_HOST_PORT=3000
```

Impact:
- changes host access port for DbGate

Risk:
- low

### `MSSQL_MCP_CONTAINER_NAME`

Purpose:
- defines the MSSQL MCP container name
- defines the backing names of the MCP data and log volumes

Consumed by:
- `mssql_mcp.container_name`
- `volumes.mssql_mcp_data.name`
- `volumes.mssql_mcp_logs.name`

Current example/default:

```env
MSSQL_MCP_CONTAINER_NAME=mssqlmcp1
```

Impact:
- renames the MCP container
- changes which Docker volumes back the MCP server state and logs

Risk:
- medium

### `MSSQL_MCP_IMAGE`

Purpose:
- selects the MSSQL MCP image

Consumed by:
- `mssql_mcp.image`

Current example/default:

```env
MSSQL_MCP_IMAGE=mcprunner/mssqlmcp:1.0.9.5
```

Impact:
- changes the MCP server implementation version
- may change tool names, authentication behavior, or runtime expectations

Risk:
- medium to high

Important note:
- this image is sourced from Docker Hub and documented at `mcprunner/mssqlmcp`
- pinning a tag is safer than relying on `latest`

### `MSSQL_MCP_HOST_PORT`

Purpose:
- publishes the MSSQL MCP HTTP endpoint on the host

Consumed by:
- `mssql_mcp.ports`

Current example/default:

```env
MSSQL_MCP_HOST_PORT=3001
```

Impact:
- changes where MCP-capable clients connect on the host

Risk:
- low

### `MSSQL_MCP_KEY`

Purpose:
- defines the master encryption key used by the MCP server to encrypt stored connection strings

Consumed by:
- `mssql_mcp.environment.MSSQL_MCP_KEY`

Current example/default:

```env
MSSQL_MCP_KEY=change-this-encryption-key
```

Impact:
- protects connection definitions persisted by the MCP server

Risk:
- high

Important notes:
- should be long and cryptographically strong
- changing it later may invalidate access to previously stored encrypted connection strings unless the server provides a supported rotation path

### `MSSQL_MCP_API_KEY`

Purpose:
- defines the API key clients must send in `X-API-Key`

Consumed by:
- `mssql_mcp.environment.MSSQL_MCP_API_KEY`

Current example/default:

```env
MSSQL_MCP_API_KEY=change-this-api-key
```

Impact:
- controls access to the MCP server endpoint

Risk:
- high

Important notes:
- should be treated as a secret
- clients such as VS Code MCP need this same value in request headers

## Recommended Configuration Practices

### For local development

- pin image versions rather than relying on floating tags where stability matters
- use strong SQL passwords even for local environments
- keep `SQLSERVER_RESTORE_ENABLED=true` only when automatic restore is desired
- avoid changing `*_CONTAINER_NAME` values casually once persistent volumes already contain useful state

### For reproducibility

- treat `.env.example` as the minimum supported contract
- document any local-only variables kept in `.env`
- if Node-RED admin credentials and `credentialSecret` should be enforced, wire them explicitly into the active Compose flow

### For security

- never commit `.env`
- rotate secrets that were previously stored in plain text if they may have leaked
- remember that Docker-level access can expose environment variables to local administrators

## Quick Change Matrix

| Variable | Safe to change anytime | May affect persisted data | Requires service recreation | Notes |
| --- | --- | --- | --- | --- |
| `TZ` | Yes | No | Yes | Timezone only |
| `NODE_RED_CONTAINER_NAME` | No | Yes | Yes | Changes Node-RED volume name |
| `NODE_RED_IMAGE` | Usually | Possibly | Yes | Validate palette compatibility |
| `NODE_RED_HOST_PORT` | Yes | No | Yes | Host port only |
| `SQLSERVER_CONTAINER_NAME` | No | Yes | Yes | Changes SQL Server volume name and hostname |
| `SQLSERVER_IMAGE` | No | Possibly | Yes | Engine/runtime compatibility matters |
| `SQLSERVER_PLATFORM` | No | No | Yes | Architecture-sensitive |
| `SQLSERVER_SA_PASSWORD` | Not on existing volumes | Yes | Yes | Existing volume keeps original real password |
| `SQLSERVER_EDITION` | Usually not casually | No | Yes | Licensing/features |
| `SQLSERVER_RESTORE_ENABLED` | Yes | No | Yes | Controls auto-restore behavior |
| `DBGATE_CONTAINER_NAME` | No | Yes | Yes | Changes DbGate state volume name |
| `DBGATE_IMAGE` | Usually | No | Yes | Runtime version changes |
| `DBGATE_HOST_PORT` | Yes | No | Yes | Host port only |
| `MSSQL_MCP_CONTAINER_NAME` | No | Yes | Yes | Changes MCP data/log volume names |
| `MSSQL_MCP_IMAGE` | Usually not casually | Possibly | Yes | MCP server behavior can change |
| `MSSQL_MCP_HOST_PORT` | Yes | No | Yes | Host port only |
| `MSSQL_MCP_KEY` | No | Yes | Yes | Can affect encrypted MCP connection storage |
| `MSSQL_MCP_API_KEY` | Yes | No | Yes | Client authentication secret |

## Related Files

- [README.md](/e:/Git/Terraform_06_SolidworksPDMSQL_Data_Loading/README.md)
- [.env.example](/e:/Git/Terraform_06_SolidworksPDMSQL_Data_Loading/.env.example)
- [.env](/e:/Git/Terraform_06_SolidworksPDMSQL_Data_Loading/.env)
- [docker-compose.yml](/e:/Git/Terraform_06_SolidworksPDMSQL_Data_Loading/docker-compose.yml)
- [templates/node-red-settings.js.tmpl](/e:/Git/Terraform_06_SolidworksPDMSQL_Data_Loading/templates/node-red-settings.js.tmpl)
