# Music pipeline: automated vs manual

Honest split of what runs itself vs what a human (or agent with a terminal) must kick off.

## Flow reminder

```
Source folder (USB / NAS / disk)
  → ingest-usb.sh          # rsync into incoming/
  → import-music.sh        # beets: FLAC + tags + art → jellyfin/media/music/
  → fetch_lyrics           # LRCLIB sidecars for FLACs missing .lrc/.txt
  → navidrome_scan         # docker exec full scan (if container up)
```

Shared library path: `jellyfin/media/music` (Jellyfin RW, Navidrome RO). Lyrics files are written on the host by the pipeline (Navidrome mounts music read-only).

## Who does what

| Phase | Automated? | Who must act |
|-------|------------|--------------|
| Find / mount source | No | Human or agent |
| Run `ingest-usb.sh` | Scripted rsync only | Must invoke |
| Run `import-music.sh` | Convert, move, art fetch scripted once import starts | Must invoke |
| MusicBrainz match choice | **No** (interactive TTY prompts) | Human/agent answers, or use `-q` / as-is fallback |
| LRCLIB lyrics after import | Yes (skips tracks that already have `.lrc`/`.txt`) | Network to lrclib.net |
| Lyrics backfill | Scripted (`./scripts/fetch-lyrics.sh`) | Must invoke |
| Navidrome scan after import | Yes, if container named `navidrome` is up | Script |
| Navidrome hourly scan | Yes (`ND_SCANSCHEDULE=1h`) | Compose |
| Jellyfin library watch | Yes (realtime monitor on Music library) | Compose |
| USB plug → auto-ingest | **None** (no udev / systemd / cron in repo) | — |

## What “automated” means here

Once `import-music.sh` is running and a match decision is made (or quiet/as-is fallback applies), beets handles:

- Convert to FLAC (`convert.auto`)
- Write tags / path layout (`$albumartist/$album/...`)
- Fetch and embed cover art (when metadata is good enough)
- Move out of `incoming/` into the shared library

Then the pipeline fetches LRCLIB lyrics into sidecar `.lrc` (synced) or `.txt` (plain) files next to each new FLAC, and Navidrome/Jellyfin pick up files without further CLI (scan trigger + realtime monitor / hourly scan). In Amperfy, sync the library after lyrics first appear; do not rely on the Navidrome web UI as the lyrics check.

## What still needs a person or agent

1. **Start the pipeline** — nothing watches folders or USB mounts.
2. **MusicBrainz decisions** — ambiguous or no-match albums need Skip / Use as-is / search / enter ID. Agent shells often lack a usable TTY; then you finish in a real terminal, or import with `beet import -q --quiet-fallback=asis` (keeps existing tags, still converts to FLAC).
3. **Verify playback** — spot-check Navidrome/Jellyfin after first import of an artist; in Amperfy, confirm lyrics on a track that got a sidecar.
4. **Redeploy compose** — env changes (e.g. Navidrome `ND_LYRICSPRIORITY`) need `docker compose up -d` in that service dir.
5. **Existing library lyrics** — one-time `./scripts/fetch-lyrics.sh` (or per album) if sidecars were never fetched.

## Agent reality (this repo)

Rough rule of thumb:

- ~70% of *work inside* a started import is automated (encode, pathing, art, scan).
- **100% of starting ingest/import** needs an explicit command.
- **MusicBrainz matching** is the main blocker for unattended agent runs. Strong matches may auto-apply; no-match / weak match needs a human or a deliberate quiet/as-is policy.

There is no ingest UI today. See [UI-SKETCH.md](UI-SKETCH.md) for where a small UI would help.
