#!/usr/bin/env bash
set -euo pipefail

VERSION="0.1.12"
APP_DIR="${HOME}/.local/share/chimera-pq"
BIN_DIR="${HOME}/.local/bin"
LOCAL_CMD="${BIN_DIR}/chimera.sh"
ARCHIVE_URL_DEFAULT="https://raw.githubusercontent.com/neo-2022/chimera/main/chimera-pq-linux-x86_64-0.1.12.tar.gz"
ARCHIVE_URL="${CHIMERA_PQ_ARCHIVE_URL:-$ARCHIVE_URL_DEFAULT}"

usage() {
  cat <<USAGE
Usage:
  chimera.sh -install
  chimera.sh -start
  chimera.sh -stop
  chimera.sh -status
  chimera.sh -restart
  chimera.sh -uninstall
  chimera.sh -version
USAGE
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: missing command: $1" >&2
    exit 1
  }
}

ensure_path_hint() {
  if ! echo ":$PATH:" | grep -q ":${BIN_DIR}:"; then
    echo "hint: add to PATH: export PATH=\"${BIN_DIR}:\$PATH\""
  fi
}

latest_main_sha() {
  env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
    curl -fsSL "https://api.github.com/repos/neo-2022/chimera/commits/main" \
    | sed -n 's/^[[:space:]]*"sha":[[:space:]]*"\([0-9a-f]\{40\}\)".*/\1/p' \
    | head -n1
}

refresh_bootstrap_if_stale() {
  [[ "${CHIMERA_BOOTSTRAP_REFRESHED:-0}" == "1" ]] && return 0
  local sha="" tmp_script="" remote_version=""
  sha="$(latest_main_sha || true)"
  [[ -n "$sha" ]] || return 0
  tmp_script="$(mktemp)"
  env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
    curl -fsSL "https://raw.githubusercontent.com/neo-2022/chimera/${sha}/chimera.sh" -o "$tmp_script" || {
      rm -f "$tmp_script"
      return 0
    }
  remote_version="$(sed -n 's/^VERSION=\"\([0-9][0-9.]*\)\"/\1/p' "$tmp_script" | head -n1)"
  if [[ -z "$remote_version" ]]; then
    rm -f "$tmp_script"
    return 0
  fi
  if [[ "$remote_version" != "$VERSION" ]]; then
    echo "bootstrap_refresh=upgrading current=$VERSION latest=$remote_version sha=$sha"
    CHIMERA_BOOTSTRAP_REFRESHED=1 bash "$tmp_script" -install
    rm -f "$tmp_script"
    exit $?
  fi
  rm -f "$tmp_script"
}

install_core() {
  refresh_bootstrap_if_stale
  need_cmd curl
  need_cmd tar
  mkdir -p "$APP_DIR" "$BIN_DIR"
  echo "bootstrap_version=${VERSION}"

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  local download_url="$ARCHIVE_URL"
  if [[ "$download_url" == *"raw.githubusercontent.com"* ]] && [[ "$download_url" != *"?"* ]]; then
    download_url="${download_url}?ts=$(date +%s)"
  fi
  echo "download_url=${download_url}"
  curl -fsSL "$download_url" -o "$tmp_dir/chimera-pq.tar.gz"
  rm -rf "$APP_DIR"/*
  tar -xzf "$tmp_dir/chimera-pq.tar.gz" -C "$APP_DIR" --strip-components=1

  if [[ ! -x "$APP_DIR/scripts/install_desktop_control.sh" ]]; then
    echo "error: install script not found in archive" >&2
    exit 1
  fi

  CHIMERA_RELEASE_VERSION="$VERSION" bash "$APP_DIR/scripts/install_desktop_control.sh"

  ln -sfn "$APP_DIR/scripts/chimera.sh" "$LOCAL_CMD"
  chmod +x "$APP_DIR/scripts/chimera.sh" "$APP_DIR/scripts/chimera-sh"

  echo "installed=ok"
  echo "command=${LOCAL_CMD}"
  ensure_path_hint
}

forward_or_fail() {
  local action="$1"
  local runtime_cmd="${APP_DIR}/scripts/chimera.sh"
  if [[ -x "$runtime_cmd" ]]; then
    exec "$runtime_cmd" "$action"
  fi
  if [[ -x "$LOCAL_CMD" ]]; then
    exec "$LOCAL_CMD" "$action"
  fi
  echo "error: CHIMERA is not installed. Run: chimera.sh -install" >&2
  exit 1
}

main() {
  case "${1:-}" in
    -install) install_core ;;
    -start) forward_or_fail -start ;;
    -stop) forward_or_fail -stop ;;
    -status) forward_or_fail -status ;;
    -restart) forward_or_fail -restart ;;
    -uninstall) forward_or_fail -uninstall ;;
    -version) echo "chimera-bootstrap ${VERSION}" ;;
    -help|--help|help|"") usage ;;
    *)
      echo "error: unknown option: ${1}" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
