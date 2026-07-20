#!/usr/bin/env bash
# Copy an album folder from a mounted USB stick into music-pipeline/incoming.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") <path-on-usb>

Copy a rip folder from a mounted USB stick into incoming/ for import.

Example:
  lsblk
  $(basename "$0") /media/\$USER/USB/Meteora
  ./scripts/import-music.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then
  usage
  exit 0
fi

SRC="$(realpath "$1")"
if [[ ! -d "$SRC" ]]; then
  echo "Error: not a directory: $1" >&2
  exit 1
fi

NAME="$(basename "$SRC")"
DEST="$INCOMING_DIR/$NAME"

echo "Ingesting:"
echo "  from: $SRC"
echo "  to:   $DEST"

mkdir -p "$DEST"
rsync -a --info=progress2 "$SRC"/ "$DEST"/

echo
echo "Done. Next:"
echo "  $SCRIPT_DIR/import-music.sh"
echo "Or import only this album:"
echo "  $SCRIPT_DIR/import-music.sh /incoming/$NAME"
