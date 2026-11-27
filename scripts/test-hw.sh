#!/usr/bin/env bash
set -euo pipefail

# Comprueba `hw` con un herdr falso: no toca el servidor real. Sin frameworks.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUNCS="${ROOT_DIR}/zsh/.config/zsh/functions.zsh"

fail() { echo "FAIL: $*"; exit 1; }

command -v zsh >/dev/null 2>&1 || { echo "AVISO: sin zsh; no se prueba hw"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "AVISO: sin jq; no se prueba hw"; exit 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
mkdir -p "${TMP}/bin" "${TMP}/home/Projects/home"
LOG="${TMP}/herdr.log"

cat >"${TMP}/bin/herdr" <<'STUB'
#!/bin/sh
echo "$*" >>"${HERDR_LOG}"
case "$1 $2" in
  "workspace list") printf '{"result":{"workspaces":%s}}\n' "${HERDR_WORKSPACES}" ;;
  "workspace create") echo '{"result":{"workspace":{"workspace_id":"w9"},"root_pane":{"pane_id":"w9:p1"}}}' ;;
esac
STUB
chmod +x "${TMP}/bin/herdr"

# run <workspaces JSON>: ejecuta hw dentro de "herdr" (HERDR_ENV=1); deja RC y OUT.
run() {
  : >"${LOG}"
  RC=0
  # shellcheck disable=SC2016 # lo expande el shell hijo
  OUT="$(HOME="${TMP}/home" HERDR_ENV=1 HERDR_LOG="${LOG}" HERDR_WORKSPACES="$1" \
    PATH="${TMP}/bin:${PATH}" zsh -f -c 'source "$1"; hw' _ "${FUNCS}" 2>&1)" || RC=$?
}

# 1. sin workspace: crea solo "home", lanza un claude y lo enfoca
run '[]'
[[ ${RC} -eq 0 ]] || fail "hw falló (${RC}): ${OUT}"
[[ "$(grep -c '^workspace create' "${LOG}")" -eq 1 ]] || fail "debe crear un solo workspace: $(<"${LOG}")"
grep -qx "workspace create --cwd ${TMP}/home/Projects/home --label home --no-focus" "${LOG}" || fail "workspace incorrecto: $(<"${LOG}")"
[[ "$(grep '^pane run' "${LOG}")" == "pane run w9:p1 claude" ]] || fail "agente incorrecto: $(<"${LOG}")"
grep -qx 'workspace focus w9' "${LOG}" || fail "no enfoca home: $(<"${LOG}")"

# 2. ya existe: no crea ni lanza nada, solo enfoca
run '[{"label":"home","workspace_id":"w3"}]'
[[ ${RC} -eq 0 ]] || fail "hw falló con home abierto (${RC}): ${OUT}"
! grep -qE '^(workspace create|pane run)' "${LOG}" || fail "duplicó home: $(<"${LOG}")"
grep -qx 'workspace focus w3' "${LOG}" || fail "no enfoca home existente: $(<"${LOG}")"

# 3. sin ~/Projects/home: falla con mensaje y no crea nada
rmdir "${TMP}/home/Projects/home"
run '[]'
[[ ${RC} -ne 0 && "${OUT}" == *"hw:"*"Projects/home"* ]] || fail "sin el Home Repo debía fallar: ${RC} ${OUT}"
! grep -q '^workspace create' "${LOG}" || fail "creó un workspace sin Home Repo"

echo "ok"
