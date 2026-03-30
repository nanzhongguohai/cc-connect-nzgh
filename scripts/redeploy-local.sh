#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BINARY_PATH="${CC_REDEPLOY_BINARY:-$ROOT_DIR/cc-connect}"
TMP_BINARY_PATH="${CC_REDEPLOY_TMP_BINARY:-$ROOT_DIR/cc-connect.new}"
BUILD_TARGET="${CC_REDEPLOY_BUILD_TARGET:-./cmd/cc-connect}"
RUN_TESTS="${CC_REDEPLOY_RUN_TESTS:-1}"
RESTART_MODE="${CC_REDEPLOY_RESTART_MODE:-auto}"
MGMT_URL="${CC_REDEPLOY_MGMT_URL:-http://127.0.0.1:9820/api/v1/restart}"
MGMT_TOKEN="${CC_REDEPLOY_MGMT_TOKEN:-}"

log() {
  printf '[redeploy] %s\n' "$*"
}

fail() {
  printf '[redeploy] ERROR: %s\n' "$*" >&2
  exit 1
}

restart_via_daemon() {
  log "restarting via daemon manager"
  "$BINARY_PATH" daemon restart
}

restart_via_management() {
  log "restarting via management api: $MGMT_URL"
  local -a curl_args
  curl_args=(-fsS -X POST "$MGMT_URL" -H "Content-Type: application/json" -d '{}')
  if [[ -n "$MGMT_TOKEN" ]]; then
    curl_args+=(-H "Authorization: Bearer $MGMT_TOKEN")
  fi
  curl "${curl_args[@]}" >/dev/null
}

restart_service() {
  case "$RESTART_MODE" in
    daemon)
      restart_via_daemon
      ;;
    management)
      restart_via_management
      ;;
    auto)
      if [[ -f "$HOME/.cc-connect/daemon.json" ]]; then
        restart_via_daemon
        return
      fi
      restart_via_management
      ;;
    *)
      fail "unsupported CC_REDEPLOY_RESTART_MODE: $RESTART_MODE"
      ;;
  esac
}

log "running from $ROOT_DIR"

if [[ "$RUN_TESTS" == "1" ]]; then
  log "running tests"
  go test ./...
else
  log "skipping tests because CC_REDEPLOY_RUN_TESTS=$RUN_TESTS"
fi

log "building binary"
go build -o "$TMP_BINARY_PATH" "$BUILD_TARGET"

log "replacing binary: $BINARY_PATH"
mv "$TMP_BINARY_PATH" "$BINARY_PATH"
chmod +x "$BINARY_PATH"

restart_service

log "redeploy completed"
