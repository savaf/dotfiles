#!/usr/bin/env bash
# herdr no está en apt/dnf/pacman/brew (salvo brew, que ya cubre el script);
# el instalador oficial funciona igual en Ubuntu/WSL, Fedora/Bazzite,
# Arch/Omarchy y macOS, así que no hace falta bifurcar por OS. Ver docs/herdr.md.
ensure_herdr() {
  exists herdr && return 0
  log "herdr no encontrado; instalando…"
  curl -fsSL https://herdr.dev/install.sh | sh
}
