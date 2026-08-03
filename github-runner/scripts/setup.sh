#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

FORCE=0
SKIP_SERVICE=0
INSTALL_SERVICE_ONLY=0

usage() {
  cat <<'EOF'
Usage: setup.sh [options]

Install and register a GitHub Actions self-hosted runner, then enable systemd autostart.

Options:
  --force                 Re-register even if .runner already exists
  --skip-service          Register/download only; do not run svc.sh install/start
  --install-service-only  Skip download/register; only install+start systemd service
  -h, --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --skip-service) SKIP_SERVICE=1; shift ;;
    --install-service-only) INSTALL_SERVICE_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -f "${STACK_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "${STACK_DIR}/.env"
  set +a
fi

GITHUB_URL="${GITHUB_URL:-https://github.com/kbario/_kbario}"
RUNNER_NAME="${RUNNER_NAME:-$(hostname -s)}"
RUNNER_DIR="${RUNNER_DIR:-${HOME}/dev/actions-runner}"
RUNNER_VERSION="${RUNNER_VERSION:-}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 1
  fi
}

fetch_registration_token() {
  if [[ -n "${RUNNER_TOKEN:-}" ]]; then
    echo "${RUNNER_TOKEN}"
    return
  fi

  require_cmd gh
  if ! gh auth status >/dev/null 2>&1; then
    echo "error: gh is not authenticated; run: gh auth login" >&2
    exit 1
  fi

  local path token_endpoint
  path="$(printf '%s' "${GITHUB_URL}" | sed -E 's#^https?://github.com/##; s#/$##')"

  if [[ "${path}" == */* ]]; then
    token_endpoint="repos/${path}/actions/runners/registration-token"
  else
    token_endpoint="orgs/${path}/actions/runners/registration-token"
  fi

  gh api -X POST "${token_endpoint}" --jq .token
}

download_runner() {
  local version tag archive url tmpdir
  mkdir -p "${RUNNER_DIR}"

  if [[ -f "${RUNNER_DIR}/config.sh" ]]; then
    echo "Runner files already present in ${RUNNER_DIR}"
    return
  fi

  require_cmd curl
  require_cmd tar

  if [[ -z "${RUNNER_VERSION}" ]]; then
    if command -v gh >/dev/null 2>&1; then
      tag="$(gh api repos/actions/runner/releases/latest --jq .tag_name)"
    else
      tag="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | sed -n 's/.*"tag_name": *"\(v[^"]*\)".*/\1/p' | head -1)"
    fi
  else
    tag="v${RUNNER_VERSION#v}"
  fi

  version="${tag#v}"
  archive="actions-runner-linux-x64-${version}.tar.gz"
  url="https://github.com/actions/runner/releases/download/${tag}/${archive}"

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' EXIT

  echo "Downloading ${url}"
  curl -fsSL "${url}" -o "${tmpdir}/${archive}"
  tar xzf "${tmpdir}/${archive}" -C "${RUNNER_DIR}"
}

configure_runner() {
  if [[ -f "${RUNNER_DIR}/.runner" && "${FORCE}" -eq 0 ]]; then
    echo "Runner already configured in ${RUNNER_DIR} (use --force to re-register)"
    return
  fi

  local token args
  token="$(fetch_registration_token)"
  args=(
    --url "${GITHUB_URL}"
    --token "${token}"
    --name "${RUNNER_NAME}"
    --unattended
  )

  if [[ -n "${RUNNER_LABELS:-}" ]]; then
    args+=(--labels "${RUNNER_LABELS}")
  fi

  if [[ "${FORCE}" -eq 1 && -f "${RUNNER_DIR}/.runner" ]]; then
    echo "Removing existing runner registration (--force)"
    (cd "${RUNNER_DIR}" && ./config.sh remove --token "${token}") || true
  fi

  echo "Registering runner ${RUNNER_NAME} -> ${GITHUB_URL}"
  (cd "${RUNNER_DIR}" && ./config.sh "${args[@]}")
}

install_service() {
  require_cmd sudo
  if [[ ! -f "${RUNNER_DIR}/svc.sh" ]]; then
    echo "error: svc.sh not found in ${RUNNER_DIR}" >&2
    exit 1
  fi

  echo "Installing systemd service (sudo required)"
  (cd "${RUNNER_DIR}" && sudo ./svc.sh install "${USER}")
  (cd "${RUNNER_DIR}" && sudo ./svc.sh start)
  (cd "${RUNNER_DIR}" && sudo ./svc.sh status)
}

main() {
  if [[ "${INSTALL_SERVICE_ONLY}" -eq 1 ]]; then
    install_service
    echo
    echo "Done. Check GitHub -> Settings -> Actions -> Runners for ${RUNNER_NAME}."
    exit 0
  fi

  download_runner
  configure_runner

  if [[ "${SKIP_SERVICE}" -eq 0 ]]; then
    install_service
  else
    echo "Skipped systemd install (--skip-service)"
  fi

  echo
  echo "Done. Check GitHub -> Settings -> Actions -> Runners for ${RUNNER_NAME}."
}

main "$@"
