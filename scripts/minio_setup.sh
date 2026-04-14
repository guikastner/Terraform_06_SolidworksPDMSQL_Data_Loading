#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  MINIO_ENDPOINT
  MINIO_ACCESS_KEY
  MINIO_SECRET_KEY
  MINIO_BUCKET_NAME
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required environment variable: ${var_name}" >&2
    exit 1
  fi
done

mc alias set codex "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" >/dev/null
mc mb --ignore-existing "codex/${MINIO_BUCKET_NAME}" >/dev/null

if [[ -n "${MINIO_BUCKET_FOLDERS:-}" ]]; then
  IFS=',' read -r -a bucket_folders <<< "${MINIO_BUCKET_FOLDERS}"
  for folder in "${bucket_folders[@]}"; do
    folder="$(printf '%s' "${folder}" | xargs)"
    [[ -n "${folder}" ]] || continue
    folder="${folder%/}"
    printf '' | mc pipe "codex/${MINIO_BUCKET_NAME}/${folder}/.keep" >/dev/null
  done
fi
