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
ln -snf "${SRC}" "${DEST}"
echo "[setup] Enlazado VS Code settings → ${DEST}"
