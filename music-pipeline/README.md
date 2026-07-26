# Music pipeline (USB → FLAC → library)

Ingest CD rips (or other audio) from a USB stick, convert to **FLAC**, tag via MusicBrainz, fetch/embed cover art, and place files in `jellyfin/media/music` for Jellyfin and Navidrome.

On-host optical ripping is not supported on this machine — rip on another PC, copy via USB, then run the scripts here.

What is automated vs what you (or an agent) must run: [AUTOMATION.md](AUTOMATION.md). UI ideas for the remaining manual steps: [UI-SKETCH.md](UI-SKETCH.md).

## Layout

```
music-pipeline/
  config/beets/config.yaml   # beets settings
  incoming/                  # staging (gitignored)
  data/                      # beets library DB (gitignored)
  scripts/
    ingest-usb.sh
    import-music.sh
    fetch-lyrics.sh          # LRCLIB → sidecar .lrc/.txt
    fetch_lyrics.py
    migrate-aiff.sh
  AUTOMATION.md              # automated vs manual / agent
  UI-SKETCH.md               # thin ingest UI sketch (not built)
```

## Typical session

```bash
# On another PC: rip the CD (prefer FLAC from EAC / whipper / XLD if you can)
# Copy the album folder onto a USB stick, plug it into this host.

lsblk                                 # find the mount, e.g. /media/$USER/USB
cd ~/.homelab/music-pipeline

./scripts/ingest-usb.sh /media/$USER/USB/Meteora
./scripts/import-music.sh             # pick the MusicBrainz match if prompted
```

After import, sources under `incoming/` are moved/converted into `jellyfin/media/music` as FLAC and removed from staging. The import then fetches **LRCLIB** sidecar lyrics (`.lrc` synced, or `.txt` plain) for any FLAC that does not already have one, then triggers a Navidrome full scan when its container is running.

Amperfy reads those lyrics from Navidrome over OpenSubsonic — sync the Amperfy library after the first lyrics land. The Navidrome web player is not the primary lyrics check.

### Backfill lyrics for the existing library

```bash
./scripts/fetch-lyrics.sh                       # whole library (skips existing sidecars)
./scripts/fetch-lyrics.sh "Artist/Album"        # one album
```

### Import only one staged album

```bash
./scripts/import-music.sh /incoming/Meteora
```

### Extra-cautious matching

```bash
./scripts/import-music.sh --timid
```

## Migrate existing untagged files

One-shot for albums already under `jellyfin/media/music` (e.g. untagged AIFFs):

```bash
./scripts/migrate-aiff.sh                        # default: Linkin Park/Meteora
./scripts/migrate-aiff.sh "Artist/Album"
```

This stages the album, removes the old files from the library tree, imports through beets (FLAC + tags + art), fetches missing sidecar lyrics, then rescans Navidrome.

## Rip elsewhere (tips)

| Tool | Platform | Notes |
|------|----------|--------|
| Exact Audio Copy (EAC) | Windows | AccurateRip; rip to FLAC or WAV |
| whipper | Linux | AccurateRip + MusicBrainz; FLAC out |
| XLD | macOS | Accurate / CD paranoia modes; FLAC out |

Untagged AIFF/WAV is fine — beets converts to FLAC and looks up tags (fingerprinting via the `chroma` plugin when needed).

## Requirements

- Docker
- USB stick mounted and readable by your user
- Navidrome container named `navidrome` (optional; scan is skipped if not running)

Beets runs via `lscr.io/linuxserver/beets` (pulled on first import). Override with `BEETS_IMAGE=...` if needed. Lyrics fetch uses `python:3.12-slim` (`LYRICS_IMAGE`) and installs `mutagen` at run time.

Navidrome should prefer sidecars via `ND_LYRICSPRIORITY=.lrc,.txt,embedded` (set in `navidrome/compose.yml`). Redeploy that stack after changing the env.
