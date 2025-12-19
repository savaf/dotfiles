#!/usr/bin/env bash
set -euo pipefail

[[ "${OSTYPE:-}" == darwin* ]] || exit 0

echo "[setup] Configurando Dock…"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock largesize -int 64
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock "workspaces-auto-swoosh" -bool false

echo "[setup] Configurando capturas de pantalla…"
SCREEN_DIR="$HOME/Pictures/Screenshots"
mkdir -p "${SCREEN_DIR}"
defaults write com.apple.screencapture location "${SCREEN_DIR}"

echo "[setup] Configurando Finder…"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

echo "[setup] Reiniciando servicios…"
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
echo "[setup] Defaults de macOS aplicados."
