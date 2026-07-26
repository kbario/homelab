#!/usr/bin/env bash
# Shared helpers for music-pipeline scripts.
set -euo pipefail

PIPELINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MUSIC_DIR="${MUSIC_DIR:-$PIPELINE_ROOT/../jellyfin/media/music}"
INCOMING_DIR="${INCOMING_DIR:-$PIPELINE_ROOT/incoming}"
DATA_DIR="${DATA_DIR:-$PIPELINE_ROOT/data}"
CONFIG_DIR="${CONFIG_DIR:-$PIPELINE_ROOT/config/beets}"
BEETS_IMAGE="${BEETS_IMAGE:-lscr.io/linuxserver/beets:latest}"
LYRICS_IMAGE="${LYRICS_IMAGE:-python:3.12-slim}"
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

# Resolve a host or library-relative path to a container path under /music.
lyrics_container_path() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    echo "/music"
    return
  fi
  if [[ "$target" == /music || "$target" == /music/* ]]; then
    echo "$target"
    return
  fi
  if [[ "$target" == "$MUSIC_DIR" || "$target" == "$MUSIC_DIR"/* ]]; then
    echo "/music/${target#"$MUSIC_DIR"/}"
    return
  fi
  # Album-relative path under the music library (e.g. Artist/Album)
  echo "/music/$target"
}

# Fetch LRCLIB sidecar lyrics for FLACs missing .lrc/.txt.
# Optional arg: album-relative path, host path under MUSIC_DIR, or /music/...
fetch_lyrics() {
  local container_path
  container_path="$(lyrics_container_path "${1:-}")"

  echo "Fetching lyrics via LRCLIB for $container_path ..."
  docker pull "$LYRICS_IMAGE" >/dev/null
  docker run --rm \
    -u "$PUID:$PGID" \
    -e HOME=/tmp \
    -e PYTHONUSERBASE=/tmp/.local \
    -v "$MUSIC_DIR:/music" \
    -v "$PIPELINE_ROOT/scripts/fetch_lyrics.py:/fetch_lyrics.py:ro" \
    --entrypoint bash \
    "$LYRICS_IMAGE" \
    -c 'set -euo pipefail
python -m pip install --user --quiet mutagen
exec python /fetch_lyrics.py "$@"' \
    bash "$container_path"
}
