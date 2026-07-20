#!/usr/bin/env bash
# Import staged music with beets: FLAC convert, MusicBrainz tags, art, then Navidrome scan.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [beets-path]

Run beets import on staging (default: /incoming). Paths are container paths
when they start with /incoming or /music; host paths under incoming/ are
mapped automatically.

Examples:
  $(basename "$0")                  # import everything in incoming/
  $(basename "$0") /incoming/Meteora
  $(basename "$0") --timid          # extra confirmation on matches
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

EXTRA_ARGS=()
TARGET="/incoming"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timid)
      EXTRA_ARGS+=(--timid)
      shift
      ;;
    -*)
      EXTRA_ARGS+=("$1")
      shift
      ;;
    *)
      TARGET="$1"
      shift
      ;;
  esac
done

# Allow host path under incoming/
if [[ "$TARGET" != /* ]]; then
  TARGET="/incoming/$TARGET"
elif [[ "$TARGET" == "$INCOMING_DIR"* ]]; then
  TARGET="/incoming/${TARGET#"$INCOMING_DIR"/}"
fi

if [[ "$TARGET" == "/incoming" ]]; then
  if [[ -z "$(find "$INCOMING_DIR" -type f \( -iname '*.flac' -o -iname '*.aiff' -o -iname '*.aif' -o -iname '*.wav' -o -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.alac' \) 2>/dev/null | head -1)" ]]; then
    echo "Nothing to import in $INCOMING_DIR" >&2
    echo "Use ./scripts/ingest-usb.sh <usb-album-path> first." >&2
    exit 1
  fi
fi

echo "Pulling beets image (if needed)..."
docker pull "$BEETS_IMAGE" >/dev/null

echo "Importing $TARGET → $MUSIC_DIR (FLAC + tags + art)"
echo "Ambiguous MusicBrainz matches will prompt interactively."
run_beet import "${EXTRA_ARGS[@]}" "$TARGET"

navidrome_scan
echo "Import finished."
