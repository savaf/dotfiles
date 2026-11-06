#!/usr/bin/env bash
# El instalador oficial funciona igual en Ubuntu/WSL, Arch/Omarchy
# y macOS, así que no hace falta bifurcar por OS. Se actualiza con `herdr update`.
# En Omarchy `exists herdr` lo cumpliría el paquete pacman (repo omarchy, desfasado):
# quitarlo con `sudo pacman -R herdr`. Ver docs/herdr.md.
ensure_herdr() {
  exists herdr && return 0
  log "herdr no encontrado; instalando…"
  curl -fsSL https://herdr.dev/install.sh | sh
}
