#!/usr/bin/env bash
set -euo pipefail

# Tests de omarchy/.local/bin/sync-config por comportamiento externo, en un HOME falso (mktemp).
# Además valida que el shell.json versionado sea JSON válido. Sin frameworks.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC="${ROOT_DIR}/omarchy/.local/bin/sync-config"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail() { echo "FAIL: $*"; exit 1; }

# Entorno nuevo: repo/ con el archivo versionado y home/ con el symlink relativo.
N=0
setup() {
  N=$((N + 1))
  local t="${TMP}/t${N}"
  mkdir -p "${t}/repo/omarchy" "${t}/home/.config/omarchy"
  echo '{"v":0}' >"${t}/repo/omarchy/shell.json"
  REPO="${t}/repo/omarchy/shell.json"
  LIVE="${t}/home/.config/omarchy/shell.json"
  ln -s ../../../repo/omarchy/shell.json "${LIVE}"
}

replace_live() { # $1 contenido: simula a Omarchy (temporal + mv sobre el symlink)
  printf '%s\n' "$1" >"${LIVE}.tmp"
  mv "${LIVE}.tmp" "${LIVE}"
}

check_restored() { # $1 contenido esperado en el repo
  [[ -L "${LIVE}" ]] || fail "el symlink no se restauró"
  [[ "$(readlink "${LIVE}")" == "../../../repo/omarchy/shell.json" ]] || fail "symlink no relativo: $(readlink "${LIVE}")"
  [[ "$(cat "${REPO}")" == "$1" ]] || fail "contenido del repo: $(cat "${REPO}")"
  [[ "$(stat -c %a "${REPO}")" == 644 ]] || fail "modo $(stat -c %a "${REPO}") distinto de 644"
}

# Idempotente: symlink intacto y archivo inexistente no hacen nada.
setup
"${SYNC}" "${LIVE}" "${REPO}" || fail "falló con symlink intacto"
[[ "$(cat "${REPO}")" == '{"v":0}' ]] || fail "tocó el repo con symlink intacto"
rm "${LIVE}"
"${SYNC}" "${LIVE}" "${REPO}" || fail "falló con archivo inexistente"
[[ ! -e "${LIVE}" ]] || fail "creó algo con archivo inexistente"

# Reemplazo suelto llega al repo con 644 y restaura el symlink.
setup
replace_live '{"v":1}'
"${SYNC}" "${LIVE}" "${REPO}"
check_restored '{"v":1}'

# Dos reemplazos seguidos.
replace_live '{"v":2}'
"${SYNC}" "${LIVE}" "${REPO}"
replace_live '{"v":3}'
"${SYNC}" "${LIVE}" "${REPO}"
check_restored '{"v":3}'

# Ráfaga de seis reemplazos; la sincronización corre dos veces y no cambia nada la segunda (sin bucle).
for i in 1 2 3 4 5 6; do replace_live "{\"burst\":${i}}"; done
"${SYNC}" "${LIVE}" "${REPO}"
before="$(stat -c %i "${REPO}")"
"${SYNC}" "${LIVE}" "${REPO}"
[[ "$(stat -c %i "${REPO}")" == "${before}" ]] || fail "la segunda corrida volvió a escribir el repo"
check_restored '{"burst":6}'

# JSON inválido: no se copia, avisa, y el archivo suelto se conserva.
setup
replace_live '{"roto":'
err="$("${SYNC}" "${LIVE}" "${REPO}" 2>&1)" || true
[[ "$(cat "${REPO}")" == '{"v":0}' ]] || fail "copió un JSON inválido"
[[ -n "${err}" ]] || fail "no avisó del JSON inválido"
[[ ! -L "${LIVE}" ]] || fail "reemplazó el archivo inválido por el symlink"

# El shell.json versionado es JSON válido.
jq empty "${ROOT_DIR}/omarchy/.config/omarchy/shell.json" || fail "shell.json versionado inválido"

echo "ok: sync-config"
