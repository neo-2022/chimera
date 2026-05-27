#!/usr/bin/env bash
set -euo pipefail

VERSION="0.1.42"
APP_DIR="${HOME}/.local/share/chimera-pq"
BIN_DIR="${HOME}/.local/bin"
LOCAL_CMD="${BIN_DIR}/chimera.sh"
ARCHIVE_URL_DEFAULT="https://raw.githubusercontent.com/neo-2022/chimera/main/chimera-pq-linux-x86_64-0.1.42.tar.gz"
ARCHIVE_URL="${CHIMERA_PQ_ARCHIVE_URL:-$ARCHIVE_URL_DEFAULT}"

usage() {
  cat <<USAGE
Usage:
  chimera.sh -install [--vps-endpoint host:port]
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

download_url_to_file() {
  local url="${1:?url_required}"
  local dest="${2:?dest_required}"
  local bootstrap_bin="${CHIMERA_BOOTSTRAP_BIN:-${APP_DIR}/bin/chimera-bootstrap}"
  if [[ -x "$bootstrap_bin" ]]; then
    "$bootstrap_bin" download --url "$url" --output "$dest"
    return $?
  fi
  if command -v curl >/dev/null 2>&1; then
    env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
      curl -fsSL "$url" -o "$dest"
    return $?
  fi
  if command -v wget >/dev/null 2>&1; then
    env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
      wget -qO "$dest" "$url"
    return $?
  fi
  echo "error: missing downloader: Rust bootstrap helper, curl, or wget" >&2
  return 1
}

ensure_path_hint() {
  if ! echo ":$PATH:" | grep -q ":${BIN_DIR}:"; then
    echo "hint: add to PATH: export PATH=\"${BIN_DIR}:\$PATH\""
  fi
}

latest_main_sha() {
  local tmp_file
  tmp_file="$(mktemp)"
  download_url_to_file "https://api.github.com/repos/neo-2022/chimera/commits/main" "$tmp_file" || {
    rm -f "$tmp_file"
    return 1
  }
  sed -n 's/^[[:space:]]*"sha":[[:space:]]*"\([0-9a-f]\{40\}\)".*/\1/p' "$tmp_file" | head -n1
  rm -f "$tmp_file"
}

refresh_bootstrap_if_stale() {
  [[ "${CHIMERA_BOOTSTRAP_REFRESHED:-0}" == "1" ]] && return 0
  local sha="" tmp_script="" remote_version=""
  sha="$(latest_main_sha || true)"
  [[ -n "$sha" ]] || return 0
  tmp_script="$(mktemp)"
  download_url_to_file "https://raw.githubusercontent.com/neo-2022/chimera/${sha}/chimera.sh" "$tmp_script" || {
      rm -f "$tmp_script"
      return 0
    }
  remote_version="$(grep -m1 '^VERSION=\"' "$tmp_script" | cut -d'\"' -f2 | tr -d '[:space:]')"
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
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --vps-endpoint|--client-endpoint|--carrier-addr)
        shift
        if [[ $# -eq 0 ]]; then
          echo "error: missing value for endpoint option" >&2
          exit 2
        fi
        export CHIMERA_VPS_ENDPOINT="$1"
        ;;
      --vps-endpoint=*|--client-endpoint=*|--carrier-addr=*)
        export CHIMERA_VPS_ENDPOINT="${1#*=}"
        ;;
      --)
        shift
        if [[ $# -gt 0 ]]; then
          echo "error: unexpected extra install arguments: $*" >&2
          exit 2
        fi
        break
        ;;
      *)
        echo "error: unknown install option: $1" >&2
        exit 2
        ;;
    esac
    shift || true
  done
  refresh_bootstrap_if_stale
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
  download_url_to_file "$download_url" "$tmp_dir/chimera-pq.tar.gz"

  local checksum_url=""
  checksum_url="${ARCHIVE_URL%.tar.gz}.sha256"
  if [[ "$checksum_url" == *"raw.githubusercontent.com"* ]] && [[ "$checksum_url" != *"?"* ]]; then
    checksum_url="${checksum_url}?ts=$(date +%s)"
  fi
  if download_url_to_file "$checksum_url" "$tmp_dir/chimera-pq.tar.gz.sha256" 2>/dev/null; then
    if command -v sha256sum >/dev/null 2>&1; then
      local expected actual
      expected="$(awk '{print $1}' "$tmp_dir/chimera-pq.tar.gz.sha256" | tr -d '[:space:]')"
      actual="$(sha256sum "$tmp_dir/chimera-pq.tar.gz" | awk '{print $1}')"
      if [[ -n "$expected" && "$expected" != "$actual" ]]; then
        echo "error: archive checksum mismatch" >&2
        echo "expected=$expected" >&2
        echo "actual=$actual" >&2
        exit 1
      fi
    fi
  fi
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
    -install) install_core "${@:2}" ;;
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
