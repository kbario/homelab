#!/usr/bin/env bash
# One-shot: move untagged library AIFFs through beets (FLAC + tags + art).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [album-subdir]

Migrate existing files already under jellyfin/media/music through beets.
Default album: Linkin Park/Meteora

Steps:
  1. Stage album into incoming/
  2. Remove originals from the library tree (replaced after import)
  3. beets import (convert → FLAC, MusicBrainz, art)
  4. Fetch LRCLIB sidecar lyrics for FLACs missing .lrc/.txt
  5. Navidrome full scan

Example:
  $(basename "$0")
  $(basename "$0") "Linkin Park/Meteora"
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

REL="${1:-Linkin Park/Meteora}"
SRC="$MUSIC_DIR/$REL"

if [[ ! -d "$SRC" ]]; then
  echo "Error: album not found: $SRC" >&2
  exit 1
fi

NAME="$(basename "$SRC")"
STAGE="$INCOMING_DIR/$NAME"

echo "Migrating: $SRC"
echo "Staging → $STAGE"

# Clear prior staging for this album name
rm -rf "$STAGE"
mkdir -p "$STAGE"
rsync -a "$SRC"/ "$STAGE"/

# Remove originals from library so beets can rewrite the same tree cleanly
rm -rf "$SRC"
# Prune empty artist dir if empty
ARTIST_DIR="$(dirname "$SRC")"
rmdir "$ARTIST_DIR" 2>/dev/null || true

echo "Pulling beets image (if needed)..."
docker pull "$BEETS_IMAGE" >/dev/null

echo "Importing (interactive MusicBrainz match if needed)..."
# Prefer non-quiet so user can pick the right release; for automation try -q first via QUIET=1
if [[ "${QUIET:-0}" == "1" ]]; then
  run_beet_ni import -q "/incoming/$NAME" || run_beet import "/incoming/$NAME"
else
  run_beet import "/incoming/$NAME"
fi

fetch_lyrics
navidrome_scan
echo "Migration finished. Check Navidrome/Jellyfin for: $REL"
