#!/usr/bin/env bash
# En Omarchy herdr viene en los paquetes base (repo omarchy) y se actualiza con
# omarchy-update; en el resto (Ubuntu/WSL, Fedora/Bazzite, macOS) se usa el
# instalador oficial, sin bifurcar por OS. Ver docs/herdr.md.
ensure_herdr() {
  exists herdr && return 0
  log "herdr no encontrado; instalando…"
  curl -fsSL https://herdr.dev/install.sh | sh
}
