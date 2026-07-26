# Vaultwarden

Self-hosted Bitwarden-compatible password manager. Tailnet-only at `https://vaultwarden.<tailnet>.ts.net`.

Household setup: signups disabled; admin creates users via the admin panel (no SMTP required).

## Bring up

```bash
cd vaultwarden
cp .env.example .env
```

Edit `.env`:

1. **`TS_AUTHKEY`** — Tailscale auth key (reuse from another stack or mint a new one).
2. **`DOMAIN`** — `https://vaultwarden.<tailnet>.ts.net` (match your MagicDNS hostname).
3. **`ADMIN_TOKEN`** — generate an argon2 hash:

```bash
docker run --rm -it vaultwarden/server:latest /vaultwarden hash
```

Paste the hash (not the raw password) into `.env`.

Start the stack:

```bash
docker compose up -d
```

## Admin panel

1. Open `https://vaultwarden.<tailnet>.ts.net/admin`
2. Enter the value from `ADMIN_TOKEN`
3. Create household users (signups are off; only admin can add accounts)

## Client setup

Use official Bitwarden apps (desktop, browser extension, mobile).

1. Settings → **Self-hosted environment** (or "Custom server" on mobile)
2. Server URL: `https://vaultwarden.<tailnet>.ts.net`
3. Log in with the account admin created for you

Enable 2FA (TOTP or WebAuthn) on each account after first login.

## Backup

Vaultwarden stores data in `./data` (SQLite + attachments + RSA keys). Back up regularly — losing this folder means losing vault data.

Run manually:

```bash
./scripts/backup.sh
```

The script uses SQLite's Online Backup API (safe while the server is running), then copies `attachments/`, `sends/`, `rsa_key*`, and `config.json` if present. Keeps the last 14 timestamped runs in `./backups/`.

Requires `sqlite3` on the host:

```bash
sudo apt install sqlite3
```

Daily cron (install on the host):

```bash
0 3 * * * /home/kbario/.homelab/vaultwarden/scripts/backup.sh
```

Copy backups off the host separately (rsync, external drive, etc.) — this script only writes local snapshots.

## Restore

1. Stop the stack: `docker compose down`
2. Restore files from a backup dir into `data/`:
   - `db.sqlite3`
   - `attachments/` (if present)
   - `sends/` (if present)
   - `rsa_key*` files
   - `config.json` (if present)
3. Start: `docker compose up -d`

Test a restore once after your first real backup to confirm the process works.

## SMTP (later)

Invite emails need SMTP. Until configured, create users directly in the admin panel. When ready, add SMTP env vars to `compose.yml` and set `INVITATIONS_ALLOWED=true` (already enabled).
