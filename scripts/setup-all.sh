#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() { echo "[setup] $*"; }

# 1) Install packages per OS
"${SCRIPT_DIR}/install-packages.sh"

# 2) Symlink dotfiles
log "Linking dotfiles (.zshrc, .p10k.zsh)..."
ln -snf "${ROOT_DIR}/.zshrc" "$HOME/.zshrc"
if [[ -f "${ROOT_DIR}/.p10k.zsh" ]]; then
  ln -snf "${ROOT_DIR}/.p10k.zsh" "$HOME/.p10k.zsh"
fi

# 3) Reload zsh config quietly
log "Reloading zsh configuration..."
if command -v zsh >/dev/null 2>&1; then
  zsh -lc "source ~/.zshrc" || true
fi

log "All set. Open a new terminal, or run: source ~/.zshrc"
