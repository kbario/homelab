# GitHub Actions runner (host service)

Self-hosted GitHub Actions runner on the homelab host. Runs as a **systemd** service (background, autostart on boot) — no terminal needed.

Not a Docker/Tailscale stack. Same pattern as [`music-pipeline/`](../music-pipeline/): host tooling documented in this repo, runner binary and credentials live **outside** the repo.

## Layout

```
github-runner/
  .env.example
  scripts/setup.sh           # download → register → systemd
  README.md
```

Runtime (gitignored / outside repo):

```
${RUNNER_DIR}/               # default: ~/dev/actions-runner
  bin/ config.sh svc.sh run.sh
  .runner .credentials       # created by config.sh — never commit
  _work/                     # job checkout dir
```

## Prerequisites

- Linux x64
- [`gh`](https://cli.github.com/) logged in with `repo` scope (for registration token)
- `curl`, `tar`, `sudo`
- Runner target already allows self-hosted runners (repo/org Settings → Actions → Runners)

## First install

```bash
cd ~/.homelab/github-runner
cp .env.example .env          # edit RUNNER_NAME / RUNNER_DIR if needed
gh auth login                 # once, if needed
./scripts/setup.sh
```

`setup.sh` will:

1. Download the latest `actions-runner` release into `RUNNER_DIR` (if missing)
2. Mint a one-time registration token via `gh api`
3. Run `config.sh --unattended`
4. Run `sudo ./svc.sh install` + `start` for systemd autostart

## Migrate to a new machine

1. **Old host:** stop service and remove runner in GitHub UI (so the name is free):

   ```bash
   cd "${RUNNER_DIR}"
   sudo ./svc.sh stop
   sudo ./svc.sh uninstall
   ```

   GitHub → Settings → Actions → Runners → remove the old runner.

2. **New host:** clone homelab repo, then:

   ```bash
   cd ~/.homelab/github-runner
   cp .env.example .env
   ./scripts/setup.sh
   ```

Do **not** copy `.credentials` or `.runner` from the old machine — re-register on the new host.

## Already registered runner (systemd only)

If the runner is configured but not yet a service (this machine before first `svc.sh install`):

```bash
cd ~/.homelab/github-runner
cp .env.example .env          # set RUNNER_DIR to existing install
./scripts/setup.sh --install-service-only
```

Or manually:

```bash
cd /home/kbario/dev/actions-runner
sudo ./svc.sh install kbario
sudo ./svc.sh start
sudo ./svc.sh status
```

## Day-2 operations

From `RUNNER_DIR`:

| Action | Command |
|--------|---------|
| Status | `sudo ./svc.sh status` |
| Stop | `sudo ./svc.sh stop` |
| Start | `sudo ./svc.sh start` |
| Uninstall service | `sudo ./svc.sh uninstall` |
| Logs | `sudo journalctl -u 'actions.runner.*' -f` |

Upgrade runner: download new release tarball into `RUNNER_DIR`, then restart the service. Re-run `./scripts/setup.sh --skip-service` only if you need to re-register.

## Script options

```bash
./scripts/setup.sh --force                 # re-register (needs remove token flow)
./scripts/setup.sh --skip-service          # download + register only
./scripts/setup.sh --install-service-only  # systemd only, existing install
```

## Security

- **Never commit** `.env`, registration tokens, `.credentials`, or `.runner`
- Registration tokens expire in about an hour — fetch fresh via `gh` or set `RUNNER_TOKEN` for a single run
- Default register target: `kbario/_kbario`. Change `GITHUB_URL` in `.env` for another repo or org URL

## Verify

GitHub → repo Settings → Actions → Runners → runner name (e.g. `kbed`) shows **Idle** / online.
