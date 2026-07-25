# Music pipeline UI sketch

Why a UI: ingest is CLI-only today. Agents and humans both hit the same friction — path pick + MusicBrainz prompts. This note scopes a thin UI; **not built yet**.

## Needs UI intervention

| Step | Why UI helps |
|------|----------------|
| Pick source path | Browse mounts (`/media/...`) or paste path; avoid remembering `ingest-usb.sh` args |
| Preview albums / track counts | Confirm what will stage before rsync |
| MusicBrainz candidate picker | Biggest gap — today `docker run -it` beets prompts; agents often cannot answer cleanly |
| Import job status + log | Tail `data/beet-import.log`; show convert progress / failures |
| Navidrome scan status | Show last scan result after import |

## Keep out of the UI (scripts/config already own this)

- FLAC convert settings
- Path layout (`config/beets/config.yaml`)
- Art fetch sources
- Hourly Navidrome schedule / Jellyfin realtime monitor

## Recommended thin approach

Small local web app (host process or Docker next to `music-pipeline/`), Tailscale-only if exposed.

**v1 (low effort, high value)**

1. Page: paste/browse source → `POST /ingest` → runs `ingest-usb.sh`.
2. List `incoming/` albums with track counts.
3. Button: “Import (quiet / as-is fallback)” → `beet import -q --quiet-fallback=asis` via existing mounts.
4. Button: “Import (interactive)” → print exact `import-music.sh` command, or open a linked terminal session.
5. Live log panel + “Scan Navidrome” button calling the same helper as `_lib.sh`.

**v2 (MusicBrainz in-browser)**

- Run import as a background job.
- When beets would prompt, surface candidates in the UI (harder: wrap beets, or pre-query MusicBrainz and pass `--search-id` / scripted answers).
- WebSocket or SSE for prompts; user clicks Apply / Skip / Use as-is.

Prefer v1 first. Most pain is “start ingest + see progress”; full prompt bridging is a larger project than the pipeline itself.

## API sketch

```
POST /api/ingest   { "sourcePath": "/media/.../Artist" }
GET  /api/incoming
POST /api/import   { "target": "/incoming/Artist", "mode": "quiet" | "interactive" }
GET  /api/import/:id/log
POST /api/scan/navidrome
```

Implementation detail: shell out to existing scripts under `music-pipeline/scripts/` so behavior stays one source of truth. Do not reimplement rsync/beets mounts in the UI process.

## Auth / safety

- Bind to localhost or Tailscale only.
- No anonymous WAN exposure (arbitrary path ingest = write into media library).
- Confirm destructive actions (re-import / wipe staging) in the UI.
