# OwnTracks

Private location tracking for the household. Phones publish GPS over MQTT; the recorder stores history; the frontend shows a live map and tracks.

Reachable at `https://owntracks.<tailnet>.ts.net` (Tailscale only). MQTT at `owntracks.<tailnet>.ts.net:1883`.

## Stack

| Container | Image | Role |
|-----------|-------|------|
| `tailscale` | `tailscale/tailscale` | HTTPS on port 443, shared network namespace |
| `mosquitto` | `eclipse-mosquitto:2` | MQTT broker |
| `recorder` | `owntracks/recorder` | Stores location history, HTTP API on `:8083` |
| `frontend` | `owntracks/frontend` | Map UI, proxies API to recorder |

## Bring up

### 1. Environment

```bash
cd owntracks
cp .env.example .env
# Edit .env: set TS_AUTHKEY and OTR_PASS (recorder MQTT password)
```

### 2. MQTT users

Create `mosquitto/config/passwd` before first start. The recorder user must match `OTR_USER` / `OTR_PASS` in `.env`.

```bash
mkdir -p mosquitto/data mosquitto/log recorder/store

# Service account for the recorder container
docker compose run --rm mosquitto mosquitto_passwd -c -b /mosquitto/config/passwd recorder YOUR_RECORDER_PASSWORD

# One user per household member (add -b flag for each)
docker compose run --rm mosquitto mosquitto_passwd -b /mosquitto/config/passwd alice ALICE_PASSWORD
docker compose run --rm mosquitto mosquitto_passwd -b /mosquitto/config/passwd bob BOB_PASSWORD
```

Edit `mosquitto/config/acl` — replace `alice` / `bob` with your usernames, or add more user blocks:

```
user <username>
topic readwrite owntracks/<username>/#
topic read owntracks/+/+
```

Usernames must be lowercase. Topic path is `owntracks/<username>/<device>`.

### 3. Start

```bash
docker compose up -d
```

On first run, initialize the recorder store if the container logs complain about a missing database:

```bash
docker compose exec recorder ot-recorder --initialize
```

### 4. Phone app

Install [OwnTracks](https://owntracks.org) on iOS or Android. Phone must be on Tailscale.

| Setting | Value |
|---------|-------|
| Mode | MQTT |
| Host | `owntracks.<tailnet>.ts.net` |
| Port | `1883` |
| TLS | off (Tailscale encrypts the path) |
| Username | your MQTT username |
| Password | your MQTT password |
| Topic | `owntracks/<username>/<device>` |

Device name: lowercase, no spaces (e.g. `phone`, `ipad`). Tracker ID (`tid`): two characters shown on map.

Publish once from the app (up-arrow) to confirm data flow.

## Verify

1. **Containers healthy** — `docker compose ps` shows all four services up.
2. **Web UI** — open `https://owntracks.<tailnet>.ts.net`; map loads.
3. **MQTT publish** — from the host (with Tailscale), subscribe and publish from the phone:

   ```bash
   mosquitto_sub -h owntracks.<tailnet>.ts.net -p 1883 \
     -u alice -P ALICE_PASSWORD -t 'owntracks/#' -v
   ```

   Tap publish in the app; a JSON location payload should appear.
4. **Frontend pin** — after publish, the map shows the device location.
5. **Bad password rejected** — `mosquitto_sub` with wrong password should fail to connect.

## Add a household user

```bash
docker compose run --rm mosquitto mosquitto_passwd -b /mosquitto/config/passwd newuser NEW_PASSWORD
```

Add ACL block in `mosquitto/config/acl`, then restart:

```bash
docker compose restart mosquitto
```

Give the person the app settings from the table above with their username/password/topic.

## Backup

- `recorder/store/` — all location history
- `mosquitto/config/passwd` — MQTT credentials (gitignored)

## Optional: reverse geocoding

Sign up at [OpenCage](https://opencagedata.com/) (free tier), add to `.env`:

```
OTR_GEOKEY=your-api-key
```

Restart recorder: `docker compose restart recorder`.

## Home Assistant later

Point Home Assistant's MQTT integration at the same broker:

- Broker: `owntracks.<tailnet>.ts.net`
- Port: `1883`
- Create a dedicated HA user in `passwd` + ACL with subscribe rights on `owntracks/#`

Configure OwnTracks device trackers or MQTT sensors from topics `owntracks/<user>/<device>`. Not wired in v1 — OwnTracks runs standalone.

## Public access later

Current setup is tailnet-only. To reach phones without Tailscale:

1. **MQTT TLS** — add a `:8883` listener in `mosquitto.conf` with Let's Encrypt or Tailscale certs; open port 8883 on router.
2. **Web UI** — set `AllowFunnel: true` in `tailscale/config/owntracks.json`, or put a public reverse proxy in front.
3. **App** — enable TLS, port 8883, provide CA cert.

No stack rewrite needed; config-only changes.
