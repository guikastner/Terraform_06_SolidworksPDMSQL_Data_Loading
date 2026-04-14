#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  MINIO_ENDPOINT
  MINIO_ACCESS_KEY
  MINIO_SECRET_KEY
  MINIO_BUCKET_NAME
  MINIO_SQLSERVER_PREFIX
  MINIO_NODE_RED_PREFIX
  SQLSERVER_CONTAINER_NAME
  SQLSERVER_SA_USERNAME
  SQLSERVER_SA_PASSWORD
  NODE_RED_CONTAINER_NAME
  BACKUP_LOCAL_DIR
  BACKUP_RETENTION_DAYS
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required environment variable: ${var_name}" >&2
    exit 1
  fi
done

mkdir -p "${BACKUP_LOCAL_DIR}"

timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
sql_backup_dir="/var/opt/mssql/backup"
node_red_archive="${BACKUP_LOCAL_DIR}/node-red-flows_${timestamp}.tgz"

mc alias set codex "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" >/dev/null
mc mb --ignore-existing "codex/${MINIO_BUCKET_NAME}" >/dev/null

sqlcmd_path="$(
  docker exec "${SQLSERVER_CONTAINER_NAME}" sh -lc '
    if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then
      printf %s /opt/mssql-tools18/bin/sqlcmd
    elif [ -x /opt/mssql-tools/bin/sqlcmd ]; then
      printf %s /opt/mssql-tools/bin/sqlcmd
    else
      exit 1
    fi
  '
)"

docker exec "${SQLSERVER_CONTAINER_NAME}" sh -lc "mkdir -p '${sql_backup_dir}'"

database_list="$(
  docker exec \
    -e SQLCMDPASSWORD="${SQLSERVER_SA_PASSWORD}" \
    -e SQLSERVER_SA_USERNAME="${SQLSERVER_SA_USERNAME}" \
    -e SQLCMD_PATH="${sqlcmd_path}" \
    "${SQLSERVER_CONTAINER_NAME}" \
    sh -lc '$SQLCMD_PATH -S localhost -U "$SQLSERVER_SA_USERNAME" -C -h -1 -W -Q "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE database_id > 4 ORDER BY name"'
)"

while IFS= read -r database_name; do
  database_name="$(printf '%s' "${database_name}" | tr -d '\r')"
  [[ -n "${database_name}" ]] || continue

  safe_name="$(printf '%s' "${database_name}" | tr ' /' '__')"
  escaped_database_name="${database_name//]/]]}"
  container_backup_path="${sql_backup_dir}/${safe_name}_${timestamp}.bak"
  local_backup_path="${BACKUP_LOCAL_DIR}/sqlserver_${safe_name}_${timestamp}.bak"

  docker exec \
    -e SQLCMDPASSWORD="${SQLSERVER_SA_PASSWORD}" \
    -e SQLSERVER_SA_USERNAME="${SQLSERVER_SA_USERNAME}" \
    -e SQLCMD_PATH="${sqlcmd_path}" \
    -e SQLSERVER_DB_NAME="${escaped_database_name}" \
    -e SQLSERVER_BACKUP_PATH="${container_backup_path}" \
    "${SQLSERVER_CONTAINER_NAME}" \
    sh -lc '$SQLCMD_PATH -S localhost -U "$SQLSERVER_SA_USERNAME" -C -Q "BACKUP DATABASE [$SQLSERVER_DB_NAME] TO DISK = N'\''$SQLSERVER_BACKUP_PATH'\'' WITH INIT, COPY_ONLY, COMPRESSION, CHECKSUM"'

  docker cp "${SQLSERVER_CONTAINER_NAME}:${container_backup_path}" "${local_backup_path}"
  docker exec "${SQLSERVER_CONTAINER_NAME}" sh -lc "rm -f '${container_backup_path}'"
  mc cp "${local_backup_path}" "codex/${MINIO_BUCKET_NAME}/${MINIO_SQLSERVER_PREFIX}/" >/dev/null
done <<< "${database_list}"

docker exec "${NODE_RED_CONTAINER_NAME}" sh -lc '
  cd /data
  if ls flows*.json >/dev/null 2>&1; then
    tar czf - flows*.json package*.json lib 2>/dev/null || tar czf - .
  else
    tar czf - .
  fi
' > "${node_red_archive}"

mc cp "${node_red_archive}" "codex/${MINIO_BUCKET_NAME}/${MINIO_NODE_RED_PREFIX}/" >/dev/null

find "${BACKUP_LOCAL_DIR}" -maxdepth 1 -type f -mtime +"${BACKUP_RETENTION_DAYS}" -delete
