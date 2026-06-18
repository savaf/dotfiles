#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIST="${ROOT_DIR}/packages/vs-extensions.txt"

if ! command -v code >/dev/null 2>&1; then
  echo "[setup] VS Code CLI (code) no encontrado"; exit 0
fi

if [[ ! -s "${LIST}" ]]; then
  echo "[setup] vs-extensions.txt vacío o no existe"; exit 0
fi

grep -Ev '^\s*#|^\s*$' "${LIST}" | while read -r ext; do
  echo "[setup] VS Code ext → ${ext}"
  code --install-extension "${ext}" --force || true
done
