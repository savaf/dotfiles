#!/usr/bin/env bash
set -euo pipefail

# Sincroniza solo lo de IA / Claude Code (sin tocar paquetes, nvim, etc.):
# stow del paquete `claude`, perfiles extra y skills + MCP. Idempotente.
# Ver docs/claude-code.md.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${ROOT_DIR}/scripts/lib/common.sh"
source "${ROOT_DIR}/scripts/modules/claude-profiles.sh"

exists stow || { log "stow no está instalado; corre scripts/bootstrap.sh primero."; exit 1; }

while IFS= read -r -d '' f; do
  rel="${f#"${ROOT_DIR}/claude/"}"
  backup_if_real "${HOME}/${rel}" "${rel}"
done < <(find "${ROOT_DIR}/claude" -type f -print0)

log "Enlazando paquete claude con stow…"
stow -d "${ROOT_DIR}" --no-folding --target="${HOME}" claude

link_claude_profiles
"${SCRIPT_DIR}/install-claude-skills.sh"
