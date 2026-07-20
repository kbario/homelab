#!/usr/bin/env bash
# Shared helpers for music-pipeline scripts.
set -euo pipefail

PIPELINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MUSIC_DIR="${MUSIC_DIR:-$PIPELINE_ROOT/../jellyfin/media/music}"
INCOMING_DIR="${INCOMING_DIR:-$PIPELINE_ROOT/incoming}"
DATA_DIR="${DATA_DIR:-$PIPELINE_ROOT/data}"
CONFIG_DIR="${CONFIG_DIR:-$PIPELINE_ROOT/config/beets}"
BEETS_IMAGE="${BEETS_IMAGE:-lscr.io/linuxserver/beets:latest}"
PUID="${PUID:-$(id -u)}"
PGID="${PGID:-$(id -g)}"

mkdir -p "$INCOMING_DIR" "$DATA_DIR" "$MUSIC_DIR"

# Run beet inside linuxserver/beets with library + staging mounts.
run_beet() {
  docker run --rm -it \
    -e PUID="$PUID" \
    -e PGID="$PGID" \
    -e TZ="${TZ:-Australia/Perth}" \
    -v "$CONFIG_DIR:/config" \
    -v "$DATA_DIR:/data" \
    -v "$MUSIC_DIR:/music" \
    -v "$INCOMING_DIR:/incoming" \
    --entrypoint beet \
    "$BEETS_IMAGE" \
    -c /config/config.yaml \
    "$@"
}

# Non-interactive variant (CI / migrate automation).
run_beet_ni() {
  docker run --rm -i \
    -e PUID="$PUID" \
    -e PGID="$PGID" \
    -e TZ="${TZ:-Australia/Perth}" \
    -v "$CONFIG_DIR:/config" \
    -v "$DATA_DIR:/data" \
    -v "$MUSIC_DIR:/music" \
    -v "$INCOMING_DIR:/incoming" \
    --entrypoint beet \
    "$BEETS_IMAGE" \
    -c /config/config.yaml \
    "$@"
}

navidrome_scan() {
  if docker ps --format '{{.Names}}' | grep -qx navidrome; then
    echo "Triggering Navidrome full scan..."
    docker exec navidrome /app/navidrome scan --full
  else
    echo "Navidrome container not running; skip scan." >&2
  fi
}
