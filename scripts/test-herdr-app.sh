#!/usr/bin/env bash
set -euo pipefail

# Comprueba ensure_herdr_app y ensure_herdr_app_keys con un curl falso: no instala nada
# ni toca ~/.config/herdr-app. Sin frameworks.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*"; exit 1; }

command -v jq >/dev/null 2>&1 || { echo "AVISO: sin jq; no se prueba herdr-app"; exit 0; }

TMP="$(mktemp -d)"
trap 'command rm -rf "${TMP}"' EXIT
mkdir -p "${TMP}/bin" "${TMP}/home/.local/bin"
LOG="${TMP}/curl.log"

# El curl falso anota los argumentos y devuelve un instalador que solo deja una marca.
cat >"${TMP}/bin/curl" <<'STUB'
#!/bin/sh
echo "$*" >>"${CURL_LOG}"
echo 'echo ran >>"${CURL_LOG}"'
STUB
chmod +x "${TMP}/bin/curl"

# shellcheck source=lib/common.sh
source "${ROOT_DIR}/scripts/lib/common.sh"
# shellcheck source=modules/herdr.sh
source "${ROOT_DIR}/scripts/modules/herdr.sh"
is_wsl() { return 1; }

# run_app <OS>: ejecuta ensure_herdr_app con PATH mínimo (sin el herdr-app real) y HOME falso.
run_app() {
  : >"${LOG}"
  OS="$1" HOME="${TMP}/home" CURL_LOG="${LOG}" PATH="${TMP}/bin:/usr/bin:/bin" ensure_herdr_app >/dev/null
}

# 1. sin la app: baja el instalador oficial y lo ejecuta
run_app omarchy
grep -qx -- '-fsSL https://releases.herdr.dev/app/install.sh' "${LOG}" || fail "URL del instalador incorrecta: $(<"${LOG}")"
grep -qx ran "${LOG}" || fail "no ejecutó el instalador: $(<"${LOG}")"

# 2. ya instalada (en ~/.local/bin, fuera del PATH del bootstrap): no hace nada
printf '#!/bin/sh\n' >"${TMP}/home/.local/bin/herdr-app"
chmod +x "${TMP}/home/.local/bin/herdr-app"
run_app macos
[[ ! -s "${LOG}" ]] || fail "reinstaló con la app presente: $(<"${LOG}")"
command rm -f "${TMP}/home/.local/bin/herdr-app"

# 3. sistemas sin build: no instala
run_app unknown
[[ ! -s "${LOG}" ]] || fail "instaló en un sistema sin build: $(<"${LOG}")"

# 4. WSL: no instala
is_wsl() { return 0; }
run_app ubuntu
[[ ! -s "${LOG}" ]] || fail "instaló en WSL: $(<"${LOG}")"
is_wsl() { return 1; }

# 5. keys.json: sin archivo, no falla ni crea nada
export HERDR_APP_HOME="${TMP}/app"
mkdir -p "${HERDR_APP_HOME}"
ensure_herdr_app_keys >/dev/null || fail "falló sin keys.json"
[[ ! -e "${HERDR_APP_HOME}/keys.json" ]] || fail "creó keys.json"

# 6. con keys.json: añade el atajo, conserva lo demás y es idempotente
printf '{"global":{"alt-1":"space.select:1"},"layout:board-v":{"ctrl-x":"tab.new"}}\n' >"${HERDR_APP_HOME}/keys.json"
ensure_herdr_app_keys >/dev/null
jq -e '.["layout:board-v"]["ctrl-shift-a"] == "board.focus"' "${HERDR_APP_HOME}/keys.json" >/dev/null || fail "no añadió ctrl-shift-a"
jq -e '.global["alt-1"] == "space.select:1" and .["layout:board-v"]["ctrl-x"] == "tab.new"' "${HERDR_APP_HOME}/keys.json" >/dev/null || fail "pisó otras teclas"
before="$(cksum <"${HERDR_APP_HOME}/keys.json")"
ensure_herdr_app_keys >/dev/null
[[ "$(cksum <"${HERDR_APP_HOME}/keys.json")" == "${before}" ]] || fail "no es idempotente"

# 7. keys.json inválido: no lo toca
printf 'no es json' >"${HERDR_APP_HOME}/keys.json"
ensure_herdr_app_keys >/dev/null
[[ "$(<"${HERDR_APP_HOME}/keys.json")" == "no es json" ]] || fail "tocó un keys.json inválido"

echo "OK: test-herdr-app"
