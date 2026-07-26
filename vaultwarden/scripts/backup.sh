#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_DIR="${STACK_DIR}/data"
BACKUP_ROOT="${STACK_DIR}/backups"
RETAIN_COUNT="${RETAIN_COUNT:-14}"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "error: sqlite3 not found on host; install it (e.g. apt install sqlite3)" >&2
  exit 1
fi

if [[ ! -f "${DATA_DIR}/db.sqlite3" ]]; then
  echo "error: database not found at ${DATA_DIR}/db.sqlite3" >&2
  exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
DEST="${BACKUP_ROOT}/${STAMP}"
mkdir -p "${DEST}"

echo "Backing up database to ${DEST}/db.sqlite3"
sqlite3 "${DATA_DIR}/db.sqlite3" ".backup '${DEST}/db.sqlite3'"

copy_if_present() {
  local name="$1"
  local src="${DATA_DIR}/${name}"
  if [[ -e "${src}" ]]; then
    cp -a "${src}" "${DEST}/"
    echo "Copied ${name}"
  fi
}

copy_if_present attachments
copy_if_present sends
copy_if_present config.json

shopt -s nullglob
for key in "${DATA_DIR}"/rsa_key*; do
  cp -a "${key}" "${DEST}/"
  echo "Copied $(basename "${key}")"
done
shopt -u nullglob

echo "Backup complete: ${DEST}"

if [[ ! -d "${BACKUP_ROOT}" ]]; then
  exit 0
fi

mapfile -t BACKUPS < <(find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r)
if ((${#BACKUPS[@]} > RETAIN_COUNT)); then
  for old in "${BACKUPS[@]:RETAIN_COUNT}"; do
    rm -rf "${BACKUP_ROOT}/${old}"
    echo "Pruned old backup: ${old}"
  done
fi
