#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT_DIR}/vscode-settings.md"
OUT_DIR="${ROOT_DIR}/vscode"
OUT_FILE="${OUT_DIR}/settings.json"

mkdir -p "${OUT_DIR}"

if [[ ! -f "${SRC}" ]]; then
  echo "[setup] ${SRC} no existe; se omite sincronización" >&2
  exit 0
fi

awk '
  /^```json/ {capture=1; next}
  /^```/ && capture {exit}
  capture {print}
' "${SRC}" > "${OUT_FILE}"

echo "[setup] Generado ${OUT_FILE}"

if [[ "${OSTYPE:-}" == "darwin"* ]]; then
  DEST="$HOME/Library/Application Support/Code/User/settings.json"
else
  DEST="$HOME/.config/Code/User/settings.json"
fi

mkdir -p "$(dirname "${DEST}")"
ln -snf "${OUT_FILE}" "${DEST}"
echo "[setup] Enlazado VS Code settings → ${DEST}"
