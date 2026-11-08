#!/usr/bin/env bash
set -euo pipefail

# Pruebas de coolercontrol-setup: el comando entero con HOME falso y curl/systemctl/
# hyprctl/coolercontrol-provision falsos al frente del PATH. Sin frameworks.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT_DIR}/coolercontrol/.local/bin/coolercontrol-setup"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
command -v jq >/dev/null || { echo "skip: falta jq"; exit 0; }

TOKEN_OK="cc_test_token_valido"
H="" F="" OUT="" RC=0
# PATH mínimo, sin el comando omarchy del host: que sea Omarchy o no lo decide solo el
# HOME falso de cada caso.
BASE_PATH="${TMP}/sysbin"
mkdir -p "${BASE_PATH}"
for c in bash cat dirname grep head install jq sed stat touch; do
  p="$(command -v "${c}")" && ln -s "${p}" "${BASE_PATH}/${c}"
done

# Entorno limpio: HOME de Omarchy con el comando y un provision falso en ~/.local/bin,
# y un daemon falso con los dos modos ya creados y Silencio activo.
reset_env() {
  H="${TMP}/home$((++N))"; F="${H}/fake"
  mkdir -p "${H}/.local/bin" "${H}/.local/share/omarchy" "${H}/.config/coolercontrol-modes" "${F}/bin" "${F}/api"
  cp "${SRC}" "${H}/.local/bin/coolercontrol-setup"
  cp "${ROOT_DIR}/coolercontrol/.config/coolercontrol-modes/gaming-classes.conf" "${H}/.config/coolercontrol-modes/"
  echo '{}' >"${H}/.config/coolercontrol-modes/curves.json"
  printf '%s' "${TOKEN_OK}" >"${F}/valid_token"
  echo '{"modes":[{"uid":"u-sil","name":"Silencio"},{"uid":"u-ren","name":"Rendimiento"}]}' >"${F}/api/modes"
  echo '{"current_mode_uid":"u-sil"}' >"${F}/api/modes-active"
  cat >"${F}/api/devices" <<'JSON'
{"devices":[{"uid":"gpu1","name":"NVIDIA GeForce RTX 3080"}]}
JSON
  cat >"${F}/api/profiles" <<'JSON'
{"profiles":[{"uid":"p-sil","name":"dotfiles-silencio-gpu-fan"},{"uid":"p-ren","name":"dotfiles-rendimiento-gpu-fan"}]}
JSON
  echo '{"settings":[{"channel_name":"fan1","profile_uid":"p-sil"},{"channel_name":"fan2","profile_uid":"p-sil"}]}' >"${F}/api/devices_gpu1_settings"
  echo '[]' >"${F}/clients.json"

  # curl falso: resuelve la ruta de la URL a un archivo de ${F}/api (las / internas
  # pasan a _), comprueba el Bearer y emula -w '\n%{http_code}'.
  cat >"${F}/bin/curl" <<'SH'
#!/usr/bin/env bash
F="$(dirname "$(dirname "$0")")"
echo "curl $*" >>"${F}/calls"
[[ -e "${F}/daemon_down" ]] && { echo "curl: (7) Failed to connect" >&2; exit 7; }
url="" auth="" method="GET" w=""
while (($#)); do
  case "$1" in
    -H) [[ "$2" == Authorization:* ]] && auth="${2#Authorization: Bearer }"; shift ;;
    -X) method="$2"; shift ;;
    -w) w="$2"; shift ;;
    -d|-m|-o) shift ;;
    http*) url="$1" ;;
  esac
  shift
done
path="${url#http://127.0.0.1:11987/}"; key="${path//\//_}"
if [[ "${auth}" != "$(<"${F}/valid_token")" ]]; then body='{"error":"Invalid Credentials"}'; code=401
elif [[ "${method}" == GET && -f "${F}/api/${key}" ]]; then body="$(<"${F}/api/${key}")"; code=200
else body='{}'; code=200; fi
printf '%s' "${body}"
[[ -n "${w}" ]] && printf '\n%s' "${code}"
exit 0
SH
  # systemctl falso: estado en archivos (enabled/active), registra cada llamada.
  cat >"${F}/bin/systemctl" <<'SH'
#!/usr/bin/env bash
F="$(dirname "$(dirname "$0")")"
echo "systemctl $*" >>"${F}/calls"
[[ "$1" == --user ]] && shift
case "$1" in
  daemon-reload) exit 0 ;;
  enable) touch "${F}/enabled" ;;
  restart) touch "${F}/active" ;;
  is-enabled) [[ -e "${F}/enabled" ]] ;;
  is-active) [[ -e "${F}/active" ]] ;;
esac
SH
  cat >"${F}/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
F="$(dirname "$(dirname "$0")")"
[[ -e "${F}/no_hyprland" ]] && exit 1
cat "${F}/clients.json"
SH
  # provision falso: registra la llamada; su salida y código salen de archivos.
  cat >"${H}/.local/bin/coolercontrol-provision" <<SH
#!/usr/bin/env bash
echo "provision" >>"${F}/calls"
[[ -f "${F}/provision_err" ]] && cat "${F}/provision_err" >&2
exit "\$(cat "${F}/provision_rc" 2>/dev/null || echo 0)"
SH
  chmod +x "${F}/bin/"* "${H}/.local/bin/"*
  : >"${F}/calls"
}

# run [args…] — corre el comando con el entorno falso; stdin lo pasa quien llama.
run() {
  RC=0
  OUT="$(HOME="${H}" XDG_STATE_HOME="" XDG_CONFIG_HOME="" PATH="${F}/bin:${BASE_PATH}" \
    "${H}/.local/bin/coolercontrol-setup" "$@" 2>&1)" || RC=$?
}
expect_rc() { [[ "${RC}" == "$1" ]] || fail "$2: salió ${RC}, esperaba $1. Salida:"$'\n'"${OUT}"; }
expect_out() { grep -qiE -- "$1" <<<"${OUT}" || fail "$2: falta /$1/ en la salida:"$'\n'"${OUT}"; }
N=0

# --- argumento desconocido → uso y código 2 ---
reset_env
run --nope </dev/null
expect_rc 2 "argumento desconocido"
expect_out 'uso' "argumento desconocido"
echo "ok: argumento desconocido"

# --- fuera de Omarchy no hace nada ---
reset_env
rm -rf "${H}/.local/share/omarchy"
run </dev/null
expect_rc 0 "fuera de Omarchy"
expect_out 'omarchy' "fuera de Omarchy"
[[ ! -s "${F}/calls" ]] || fail "fuera de Omarchy llamó a: $(<"${F}/calls")"
echo "ok: fuera de Omarchy"

# --- camino feliz: token válido por stdin → guardado 600, provision, watcher, todo OK ---
reset_env
run <<<"${TOKEN_OK}"
expect_rc 0 "camino feliz"
TOK="${H}/.local/state/coolercontrol-modes/api-token"
[[ "$(<"${TOK}")" == "${TOKEN_OK}" ]] || fail "camino feliz: el token no se guardó tal cual"
[[ "$(stat -c %a "${TOK}")" == 600 ]] || fail "camino feliz: token con permisos $(stat -c %a "${TOK}")"
[[ "$(stat -c %a "$(dirname "${TOK}")")" == 700 ]] || fail "camino feliz: directorio no es 700"
grep -q '^provision$' "${F}/calls" || fail "camino feliz: no aprovisionó"
grep -q 'systemctl --user enable coolercontrol-mode-watcher' "${F}/calls" || fail "camino feliz: no habilitó el watcher"
grep -q 'systemctl --user restart coolercontrol-mode-watcher' "${F}/calls" || fail "camino feliz: no reinició el watcher"
grep -q "${TOKEN_OK}" <<<"${OUT}" && fail "camino feliz: el token aparece en la salida"
for c in 'daemon' 'token' 'modos' 'watcher' 'modo activo' 'gpu'; do expect_out "OK.*${c}" "camino feliz"; done
grep -qi 'FALLO' <<<"${OUT}" && fail "camino feliz: hubo FALLO:"$'\n'"${OUT}"
echo "ok: camino feliz"

# Deja un token válido ya guardado y el watcher habilitado/activo (estado tras un setup).
seed_setup() {
  install -d -m 700 "${H}/.local/state/coolercontrol-modes"
  (umask 077 && printf '%s' "${TOKEN_OK}" >"${H}/.local/state/coolercontrol-modes/api-token")
  touch "${F}/enabled" "${F}/active"
}

# --- token rechazado (401) → no se guarda, código 1 ---
reset_env
run <<<"cc_token_malo"
expect_rc 1 "token rechazado"
expect_out 'rechazado' "token rechazado"
[[ ! -e "${H}/.local/state/coolercontrol-modes/api-token" ]] || fail "token rechazado: se guardó"
grep -q '^provision$' "${F}/calls" && fail "token rechazado: aprovisionó igual"
echo "ok: token rechazado"

# --- sin token y sin TTY → FALLO, no aprovisiona ---
reset_env
run </dev/null
expect_rc 1 "sin token"
expect_out 'FALLO.*token' "sin token"
grep -q '^provision$' "${F}/calls" && fail "sin token: aprovisionó igual"
echo "ok: sin token"

# --- daemon caído → mensaje específico ---
reset_env
touch "${F}/daemon_down"
run <<<"${TOKEN_OK}"
expect_rc 1 "daemon caído"
expect_out 'coolercontrold no responde' "daemon caído"
echo "ok: daemon caído"

# --- provision falla con 403 → sin permiso de escritura ---
reset_env
echo 1 >"${F}/provision_rc"
echo '[coolercontrol-provision] ERROR: POST /profiles → HTTP 403: {"error":"This token does not have write access."}' >"${F}/provision_err"
run <<<"${TOKEN_OK}"
expect_rc 1 "provision 403"
expect_out 'sin permiso de escritura' "provision 403"
grep -q 'restart' "${F}/calls" && fail "provision 403: reinició el watcher igual"
echo "ok: provision 403"

# --- --check no cambia nada ---
reset_env
seed_setup
run --check </dev/null
expect_rc 0 "--check"
grep -qE '^provision$|systemctl --user (enable|restart|daemon-reload)' "${F}/calls" \
  && fail "--check cambió algo: $(<"${F}/calls")"
echo "ok: --check"

# --- juego abierto: Silencio activo es FALLO, Rendimiento con perfiles de GPU es OK ---
reset_env
seed_setup
echo '[{"class":"steam_app_1245620","initialClass":"steam_app_1245620"}]' >"${F}/clients.json"
run --check </dev/null
expect_rc 1 "juego con Silencio"
expect_out 'FALLO.*modo activo.*Rendimiento' "juego con Silencio"
echo '{"current_mode_uid":"u-ren"}' >"${F}/api/modes-active"
echo '{"settings":[{"channel_name":"fan1","profile_uid":"p-ren"},{"channel_name":"fan2","profile_uid":"p-ren"}]}' >"${F}/api/devices_gpu1_settings"
run --check </dev/null
expect_rc 0 "juego con Rendimiento"
expect_out 'OK.*gpu fan1.*dotfiles-rendimiento-gpu-fan' "juego con Rendimiento"
echo "ok: modo según juego abierto"

# --- sin Hyprland: el modo activo se omite, no falla ---
reset_env
seed_setup
touch "${F}/no_hyprland"
run --check </dev/null
expect_rc 0 "sin Hyprland"
expect_out 'OMITE.*modo activo' "sin Hyprland"
echo "ok: sin Hyprland"

# --- idempotente: la segunda vez no pide token y da lo mismo ---
reset_env
run <<<"${TOKEN_OK}"
expect_rc 0 "idempotencia (1ª)"
run </dev/null
expect_rc 0 "idempotencia (2ª)"
grep -qi 'pégalo|token guardado' <<<"${OUT}" && fail "idempotencia: volvió a pedir/guardar el token"
echo "ok: idempotente"

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${SRC}" || fail "shellcheck de coolercontrol-setup"
  echo "ok: shellcheck"
fi
