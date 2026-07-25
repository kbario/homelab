# Gonic (podcasts)

Subsonic server for podcasts. Music stays on [Navidrome](../navidrome/); this stack owns RSS subscribe + episode downloads under `jellyfin/media/podcasts`.

Reachable at `https://gonic.<tailnet>.ts.net` (Tailscale only).

## Bring up

```bash
cd gonic
cp .env.example .env   # set TS_AUTHKEY
mkdir -p data/playlists data/cache
docker compose up -d
```

Default login: **admin** / **admin** — change password in the web UI immediately.

## Add podcasts

1. Open `https://gonic.<tailnet>.ts.net`
2. Settings → Podcasts → add RSS feed URLs (e.g. Hardcore History)
3. Episodes download into `../jellyfin/media/podcasts` (shared with Jellyfin)

Existing files already in that folder stay on disk. Re-add RSS so Gonic has channel metadata for Amperfy; overlapping episodes may re-download — prune duplicates if needed.

## Amperfy

1. Keep the existing Navidrome account for music
2. Add server → Subsonic
3. URL: `https://gonic.<tailnet>.ts.net`
4. Username/password from Gonic
5. Sync — podcasts show in Amperfy’s podcast UI

Amperfy needs the server to own the feeds (Subsonic podcast API). Audiobookshelf will not work with Amperfy.
