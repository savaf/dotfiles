#!/usr/bin/env bash
# El instalador oficial funciona igual en Ubuntu/WSL, Fedora/Bazzite, Arch/Omarchy
# y macOS, así que no hace falta bifurcar por OS. En Omarchy herdr ya viene en los
# paquetes base (repo omarchy) y se actualiza con omarchy-update. Ver docs/herdr.md.
ensure_herdr() {
  exists herdr && return 0
  log "herdr no encontrado; instalando…"
  curl -fsSL https://herdr.dev/install.sh | sh
}
