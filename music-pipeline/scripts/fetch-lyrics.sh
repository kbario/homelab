#!/usr/bin/env bash
# Fetch sidecar .lrc/.txt lyrics from LRCLIB for FLACs in the music library.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [album-subdir|/music-path]

Fetch LRCLIB lyrics into sidecar files next to each FLAC.
Skips tracks that already have a matching .lrc or .txt.

Examples:
  $(basename "$0")                       # whole library
  $(basename "$0") "Artist/Album"        # one album under jellyfin/media/music
  $(basename "$0") /music/Artist/Album   # container path (used by helpers)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

TARGET="${1:-}"
fetch_lyrics "$TARGET"
