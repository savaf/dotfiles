#!/usr/bin/env bash
set -euo pipefail

# Symlinks the version-controlled VS Code settings.json into the OS-specific
# user settings location. Works on both Ubuntu/WSL and macOS.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT_DIR}/vscode/settings.json"

if [[ ! -f "${SRC}" ]]; then
  echo "[setup] ${SRC} no existe; se omite sincronización" >&2
  exit 0
fi

if [[ "${OSTYPE:-}" == "darwin"* ]]; then
  DEST="$HOME/Library/Application Support/Code/User/settings.json"
else
  DEST="$HOME/.config/Code/User/settings.json"
fi

mkdir -p "$(dirname "${DEST}")"
# Back up a real (non-symlink) settings.json before replacing it with our symlink.
if [[ -e "${DEST}" && ! -L "${DEST}" ]]; then
  bak="${DEST}.bak.$(date +%Y%m%d_%H%M%S)"
  mv "${DEST}" "${bak}"
  echo "[setup] Backup settings.json existente → ${bak}" >&2
fi
ln -snf "${SRC}" "${DEST}"
echo "[setup] Enlazado VS Code settings → ${DEST}"
