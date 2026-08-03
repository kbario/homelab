# HOME LAB

A self-hosted homelab. Each service is its own independent Docker Compose stack, and every stack is exposed privately over [Tailscale](https://tailscale.com) — reachable from anywhere on the tailnet, but never the public internet.

## Architecture

The host runs Docker. Each service directory is a standalone Compose stack that bundles the app with a Tailscale sidecar container. The app joins the sidecar's network namespace (`network_mode: service:tailscale`), and the sidecar serves the app over HTTPS on port 443 onto the tailnet.

```mermaid
flowchart LR
  subgraph host [Docker Host]
    subgraph ha [home-assistant stack]
      tsHA[tailscale sidecar] --> HA[Home Assistant]
      tsHA --> Matter[matter-server]
    end
    subgraph jf [jellyfin stack]
      tsJF[tailscale sidecar] --> JF[Jellyfin]
    end
    subgraph im [immich stack]
      tsIM[tailscale sidecar] --> IMS[immich-server]
      IMS --> DB[(postgres/pgvector)]
      IMS --> Redis[(valkey)]
      IMS --> ML[machine-learning]
    end
    subgraph nd [navidrome stack]
      tsND[tailscale sidecar] --> ND[Navidrome]
    end
    subgraph go [gonic stack]
      tsGO[tailscale sidecar] --> GO[Gonic]
    end
    subgraph ot [owntracks stack]
      tsOT[tailscale sidecar] --> MQTT[Mosquitto]
      tsOT --> FE[Frontend]
      MQTT --> REC[Recorder]
      FE --> REC
    end
    subgraph vw [vaultwarden stack]
      tsVW[tailscale sidecar] --> VW[Vaultwarden]
    end
  end
  Tailnet((Tailnet)) --- tsHA
  Tailnet --- tsJF
  Tailnet --- tsIM
  Tailnet --- tsND
  Tailnet --- tsGO
  Tailnet --- tsOT
  Tailnet --- tsVW
```

## Access

Each service is reachable at `https://<service>.<tailnet>.ts.net` via Tailscale MagicDNS. The sidecar terminates HTTPS on port 443 using Tailscale-issued certs. `AllowFunnel` is `false` on every stack, so access is tailnet-only — nothing is published to the public internet.

## Services

- **`home-assistant/`** — Home Assistant plus a Matter server for smart-home devices. Runs privileged with host `dbus` and Bluetooth access; `TZ=Australia/Perth`.
- **`jellyfin/`** — Media server. Binds `media/` (music, podcasts) and `media2/` (read-only spare). Movies library bind-mounts `/media/kbario/The Bank/Personal/Media/Movies` read-only onto `/media/movies` (see `compose.yml`); keep The Bank plugged in. One-time host mount: `sudo jellyfin/scripts/install-the-bank-fstab.sh`. Custom `fonts/` for subtitle burn-in.
- **`immich/`** — Photo and video backup. Composed of `immich-server`, `immich-machine-learning`, `valkey` (redis), and `postgres` (pgvector). Reads `UPLOAD_LOCATION`, DB credentials, and `DB_DATA_LOCATION` from `.env`.
- **`navidrome/`** — Music streaming (OpenSubsonic). Bind-mounts `jellyfin/media/music` read-only; data in `navidrome/data/`. Shares files with Jellyfin but scrapes its own art/metadata (Last.fm + Deezer); set `ND_LASTFM_APIKEY` / `ND_LASTFM_SECRET` in `navidrome/.env`. No podcasts — use Gonic for that.
- **`gonic/`** — Podcasts (Subsonic). Bind-mounts `jellyfin/media/podcasts` read-write for RSS downloads; empty local `music/` stub (music stays on Navidrome). In Amperfy: Navidrome account = music, second Gonic account = podcasts. See [`gonic/README.md`](gonic/README.md).
- **`owntracks/`** — Private location tracking (MQTT + Recorder + Frontend). Tailnet-only; phones publish over MQTT, map at `https://owntracks.<tailnet>.ts.net`. See [`owntracks/README.md`](owntracks/README.md).
- **`vaultwarden/`** — Password manager (Bitwarden-compatible). SQLite in `data/`; signups disabled, admin creates household users. See [`vaultwarden/README.md`](vaultwarden/README.md).
- **`music-pipeline/`** — USB ingest tooling (not a Tailscale service). Copies rips from a USB stick, converts to FLAC, tags via beets/MusicBrainz, writes into `jellyfin/media/music`. See [`music-pipeline/README.md`](music-pipeline/README.md).
- **`github-runner/`** — Self-hosted GitHub Actions runner (host systemd service, not Docker). Bootstrap and migrate with `./scripts/setup.sh`. See [`github-runner/README.md`](github-runner/README.md).

## Prerequisites

- Docker with the Compose plugin.
- A Tailscale auth key for the tailnet.
- A per-stack `.env` file (only `.env` is gitignored) providing at least `TS_AUTHKEY`. The `immich` stack also needs `UPLOAD_LOCATION`, `DB_DATA_LOCATION`, `DB_USERNAME`, `DB_PASSWORD`, and `DB_DATABASE_NAME`.

## Quickstart

Bring up any service from its own directory:

```bash
cd <service>          # home-assistant | jellyfin | immich | navidrome | gonic | owntracks | vaultwarden
cp .env.example .env  # or create .env with the vars above
docker compose up -d
```

Once the sidecar authenticates, the service appears on the tailnet at `https://<service>.<tailnet>.ts.net`.

Host-only tooling (no Compose):

```bash
cd github-runner
cp .env.example .env
./scripts/setup.sh
```

## Repo layout

Each top-level directory is one Compose stack:

```
<service>/
  compose.yml          # the stack definition
  tailscale/
    config/            # Tailscale serve config (HTTPS -> app port)
    state/             # tailscale state + issued certs
  <service data dirs>  # config, cache, media, db data, etc.
```

Note: runtime data (service `config/`, `cache/`, logs, and Tailscale certs) currently lives in-repo rather than being ignored.

## Goals / TODO

No firm roadmap yet. Candidate directions to flesh out later:

- Define a backup strategy for service data and databases.
- Move secrets and Tailscale certs out of the git repo.
- Add monitoring / uptime checks across the stacks.
