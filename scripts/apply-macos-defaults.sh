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

echo "[setup] Remapeando Caps Lock → Escape…"
# Caps Lock (0x700000039) → Escape (0x700000029). hidutil aplica al instante pero
# no persiste tras reboot; el LaunchAgent lo reaplica en cada login.
HIDUTIL_SET='hidutil property --set '\''{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029}]}'\'
eval "${HIDUTIL_SET}" >/dev/null

# ponytail: el plist se genera aquí en vez de comitearlo, para no añadir un archivo al repo.
LABEL="com.dotfiles.capslock-escape"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
mkdir -p "$(dirname "${PLIST}")"
cat > "${PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LABEL}</string>
  <key>RunAtLoad</key><true/>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/hidutil</string>
    <string>property</string>
    <string>--set</string>
    <string>{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029}]}</string>
  </array>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "${PLIST}" 2>/dev/null || true

echo "[setup] Reiniciando servicios…"
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
echo "[setup] Defaults de macOS aplicados."
