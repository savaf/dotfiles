#!/usr/bin/env bash
set -euo pipefail

# Branding por hostname: cada About versionado cabe en 54x26 y el selector enlaza el de la
# máquina actual (con HOME falso; nunca toca el HOME real).
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANDING="${ROOT_DIR}/omarchy/.config/omarchy/branding"
SELECT="${ROOT_DIR}/omarchy/.local/bin/branding-select"

fail() { echo "FAIL: $*" >&2; exit 1; }

# --- cada about.<host>.txt cabe en la caja de About (54 columnas x 26 filas) ---
shopt -s nullglob
abouts=("${BRANDING}"/about.*.txt)
[[ ${#abouts[@]} -ge 2 ]] || fail "faltan archivos about.<host>.txt en ${BRANDING}"
for f in "${abouts[@]}"; do
  cols="$(LC_ALL=C.UTF-8 wc -L <"${f}")"
  rows="$(wc -l <"${f}")"
  (( cols <= 54 )) || fail "${f##*/}: ${cols} columnas (máx 54)"
  (( rows <= 26 )) || fail "${f##*/}: ${rows} filas (máx 26)"
done
echo "OK: abouts caben en 54x26"

# --- selector ---
[[ -x "${SELECT}" ]] || fail "branding-select no existe o no es ejecutable"
TMP="$(mktemp -d)"
trap 'rm -r "${TMP}"' EXIT
LINK="${TMP}/.config/omarchy/branding/about.txt"

run() { HOME="${TMP}" BRANDING_HOSTNAME="$1" bash "${SELECT}"; }

# 1. enlaza el About del hostname y respalda el About genérico previo (archivo suelto)
mkdir -p "${TMP}/.config/omarchy/branding"
printf 'por defecto\n' >"${LINK}"
run andrea
[[ -L "${LINK}" ]] || fail "about.txt no es un enlace"
[[ "$(readlink -f "${LINK}")" == "$(readlink -f "${BRANDING}/about.andrea.txt")" ]] \
  || fail "about.txt no apunta a about.andrea.txt"
[[ "$(cat "${LINK}.bak")" == "por defecto" ]] || fail "no respaldó el About previo"
echo "OK: enlaza andrea y respalda el previo"

# 2. cambia de hostname e idempotencia
run songbird
[[ "$(readlink -f "${LINK}")" == "$(readlink -f "${BRANDING}/about.songbird.txt")" ]] || fail "no cambió a songbird"
run songbird
[[ "$(readlink -f "${LINK}")" == "$(readlink -f "${BRANDING}/about.songbird.txt")" ]] || fail "no es idempotente"
echo "OK: songbird e idempotente"

# 3. hostname desconocido: sale 0, avisa y deja el enlace como estaba
before="$(readlink "${LINK}")"
err="$(run desconocido 2>&1 >/dev/null)" || fail "hostname desconocido debe salir 0"
[[ -n "${err}" ]] || fail "hostname desconocido debe avisar por stderr"
[[ "$(readlink "${LINK}")" == "${before}" ]] || fail "hostname desconocido cambió el enlace"
echo "OK: hostname desconocido no rompe nada"

# 4. mayúsculas y dominio en el hostname
run SONGBIRD.local
[[ "$(readlink -f "${LINK}")" == "$(readlink -f "${BRANDING}/about.songbird.txt")" ]] || fail "no normaliza hostname"
echo "OK: normaliza hostname"

# 5. HOME sin about.txt previo (primer arranque)
rm -r "${TMP}/.config"
run andrea
[[ -L "${LINK}" ]] || fail "no crea el enlace en un HOME vacío"
echo "OK: HOME vacío"
