#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  SQLSERVER_CONTAINER_NAME
  SQLSERVER_SA_USERNAME
  SQLSERVER_SA_PASSWORD
  SQLSERVER_RESTORE_FILES
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required environment variable: ${var_name}" >&2
    exit 1
  fi
done

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

docker exec "${SQLSERVER_CONTAINER_NAME}" sh -lc "mkdir -p /var/opt/mssql/backup /var/opt/mssql/data"

run_sqlcmd() {
  local query="$1"
  docker exec \
    -e SQLCMDPASSWORD="${SQLSERVER_SA_PASSWORD}" \
    -e SQLSERVER_SA_USERNAME="${SQLSERVER_SA_USERNAME}" \
    -e SQLCMD_PATH="${sqlcmd_path}" \
    -e SQLSERVER_QUERY="${query}" \
    "${SQLSERVER_CONTAINER_NAME}" \
    sh -lc '$SQLCMD_PATH -S localhost -U "$SQLSERVER_SA_USERNAME" -C -s "|" -W -h -1 -Q "$SQLSERVER_QUERY"'
}

IFS=':' read -r -a restore_files <<< "${SQLSERVER_RESTORE_FILES}"

for restore_file in "${restore_files[@]}"; do
  [[ -n "${restore_file}" ]] || continue
  [[ -f "${restore_file}" ]] || {
    echo "Restore source file not found: ${restore_file}" >&2
    exit 1
  }

  bak_name="$(basename "${restore_file}")"
  container_bak_path="/var/opt/mssql/backup/${bak_name}"

  docker cp "${restore_file}" "${SQLSERVER_CONTAINER_NAME}:${container_bak_path}"

  db_name="$(run_sqlcmd "RESTORE HEADERONLY FROM DISK = N'${container_bak_path}'" | head -n 1 | cut -d'|' -f11 | tr -d '\r')"

  if [[ -z "${db_name}" ]]; then
    echo "Could not extract original database name from backup header: ${restore_file}" >&2
    exit 1
  fi

  escaped_db_name="${db_name//]/]]}"

  file_list="$(run_sqlcmd "RESTORE FILELISTONLY FROM DISK = N'${container_bak_path}'")"

  data_index=0
  log_index=0
  move_clauses=()

  while IFS='|' read -r logical_name physical_name file_type _rest; do
    logical_name="$(printf '%s' "${logical_name}" | tr -d '\r')"
    file_type="$(printf '%s' "${file_type}" | tr -d '\r')"
    [[ -n "${logical_name}" ]] || continue

    case "${file_type}" in
      L)
        log_index=$((log_index + 1))
        if [[ ${log_index} -eq 1 ]]; then
          target_path="/var/opt/mssql/data/${db_name}_log.ldf"
        else
          target_path="/var/opt/mssql/data/${db_name}_log${log_index}.ldf"
        fi
        ;;
      *)
        data_index=$((data_index + 1))
        if [[ ${data_index} -eq 1 ]]; then
          target_path="/var/opt/mssql/data/${db_name}.mdf"
        else
          target_path="/var/opt/mssql/data/${db_name}_${data_index}.ndf"
        fi
        ;;
    esac

    escaped_logical_name="${logical_name//\'/\'\'}"
    move_clauses+=("MOVE N'${escaped_logical_name}' TO N'${target_path}'")
  done <<< "${file_list}"

  if [[ ${#move_clauses[@]} -eq 0 ]]; then
    echo "Could not extract logical files from backup: ${restore_file}" >&2
    exit 1
  fi

  move_clause_sql="$(printf ', %s' "${move_clauses[@]}")"
  move_clause_sql="${move_clause_sql:2}"

  restore_query=$(
    cat <<EOF
IF DB_ID(N'${escaped_db_name}') IS NOT NULL
BEGIN
  ALTER DATABASE [${escaped_db_name}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
END;
RESTORE DATABASE [${escaped_db_name}]
FROM DISK = N'${container_bak_path}'
WITH REPLACE, RECOVERY, ${move_clause_sql};
ALTER DATABASE [${escaped_db_name}] SET MULTI_USER;
EOF
  )

  run_sqlcmd "${restore_query}" >/dev/null
  docker exec "${SQLSERVER_CONTAINER_NAME}" sh -lc "rm -f '${container_bak_path}'"
done
