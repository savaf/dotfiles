#!/usr/bin/env bash
# Cachea credenciales sudo una vez y las mantiene vivas hasta que el proceso
# que llamó a require_sudo termine. Linux-only (en macOS sudo se pide aparte).
require_sudo() {
  [[ "$OSTYPE" == darwin* ]] && return 0
  # Ya hay un keep-alive heredado del proceso padre (p.ej. bootstrap.sh): no repreguntar.
  [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && return 0
  command -v sudo >/dev/null 2>&1 || { echo "[setup] sudo is required"; exit 1; }
  sudo -v                                               # prompt único
  # shellcheck disable=SC2064
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
  while true; do sudo -n true; sleep 60; done &
  export SUDO_KEEPALIVE_PID=$!
}
