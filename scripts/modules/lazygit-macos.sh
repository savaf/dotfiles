#!/usr/bin/env bash
# On macOS lazygit reads its config from ~/Library/Application Support/lazygit,
# not ~/.config. Symlink the stowed config there (mirrors the VS Code approach).
link_lazygit_macos() {
  [[ "${OS}" == "macos" ]] || return 0
  local src="${ROOT_DIR}/lazygit/.config/lazygit/config.yml"
  [[ -f "${src}" ]] || return 0
  local dest="$HOME/Library/Application Support/lazygit/config.yml"
  mkdir -p "$(dirname "${dest}")"
  backup_if_real "${dest}" "lazygit-config.yml.macos"
  ln -snf "${src}" "${dest}"
  log "Enlazado lazygit config → ${dest}"
}
