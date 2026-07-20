# Music pipeline (USB → FLAC → library)

Ingest CD rips (or other audio) from a USB stick, convert to **FLAC**, tag via MusicBrainz, fetch/embed cover art, and place files in `jellyfin/media/music` for Jellyfin and Navidrome.

On-host optical ripping is not supported on this machine — rip on another PC, copy via USB, then run the scripts here.

## Layout

```
music-pipeline/
  config/beets/config.yaml   # beets settings
  incoming/                  # staging (gitignored)
  data/                      # beets library DB (gitignored)
  scripts/
    ingest-usb.sh
    import-music.sh
    migrate-aiff.sh
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

After import, sources under `incoming/` are moved/converted into `jellyfin/media/music` as FLAC and removed from staging. Navidrome gets a full scan when its container is running.

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

This stages the album, removes the old files from the library tree, imports through beets (FLAC + tags + art), then rescans Navidrome.

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

Beets runs via `lscr.io/linuxserver/beets` (pulled on first import). Override with `BEETS_IMAGE=...` if needed.
