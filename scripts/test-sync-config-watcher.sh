#!/usr/bin/env bash
set -euo pipefail

# Pruebas del vigilante: wrapper sync-config-watch, unidades systemd de usuario y el paso
# ensure_sync_config_watcher del instalador (HOME falso y systemctl falso). Sin frameworks.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

# --- wrapper: resuelve el repo desde su propio symlink y sincroniza los dos archivos ---
PKG="${TMP}/repo/omarchy"
H="${TMP}/home"
mkdir -p "${PKG}/.local/bin" "${PKG}/.config/omarchy" "${PKG}/.config/hypr" \
  "${H}/.local/bin" "${H}/.config/omarchy" "${H}/.config/hypr"
for s in sync-config sync-config-watch; do
  cp "${ROOT_DIR}/omarchy/.local/bin/${s}" "${PKG}/.local/bin/${s}"
  ln -s "${PKG}/.local/bin/${s}" "${H}/.local/bin/${s}"
done
watch() { HOME="${H}" "${H}/.local/bin/sync-config-watch"; }
echo '{"v":0}' >"${PKG}/.config/omarchy/shell.json"
echo '-- 0' >"${PKG}/.config/hypr/monitors.lua"
echo '{"v":1}' >"${H}/.config/omarchy/shell.json"   # Omarchy lo reemplazó
echo '-- 1' >"${H}/.config/hypr/monitors.lua"
watch
[[ -L "${H}/.config/omarchy/shell.json" && -L "${H}/.config/hypr/monitors.lua" ]] \
  || fail "los enlaces no se restauraron"
grep -q '"v":1' "${PKG}/.config/omarchy/shell.json" || fail "shell.json no llegó al repo"
grep -q -- '-- 1' "${PKG}/.config/hypr/monitors.lua" || fail "monitors.lua no llegó al repo"
watch || fail "no es idempotente"
# Un archivo ausente (stow -R a medias) no es un error ni crea nada.
rm "${H}/.config/hypr/monitors.lua"
watch || fail "falla con archivo ausente"
[[ ! -e "${H}/.config/hypr/monitors.lua" ]] || fail "creó un archivo ausente"
# Un JSON inválido no se copia y no impide sincronizar el otro archivo.
echo '-- 2' >"${H}/.config/hypr/monitors.lua"
rm "${H}/.config/omarchy/shell.json"
echo '{rota' >"${H}/.config/omarchy/shell.json"
if watch 2>/dev/null; then fail "debía propagar el error del JSON"; fi
grep -q -- '-- 2' "${PKG}/.config/hypr/monitors.lua" || fail "el JSON inválido bloqueó monitors.lua"
grep -q '"v":1' "${PKG}/.config/omarchy/shell.json" || fail "el JSON inválido llegó al repo"
echo "ok: wrapper"

# --- unidades ---
U="${ROOT_DIR}/omarchy/.config/systemd/user"
for p in omarchy hypr; do
  f="${U}/sync-config-${p}.path"
  grep -q "^PathChanged=%h/.config/${p}$" "${f}" || fail "${f##*/}: falta PathChanged"
  grep -q '^Unit=sync-config.service$' "${f}" || fail "${f##*/}: falta Unit="
  grep -q '^WantedBy=paths.target$' "${f}" || fail "${f##*/}: falta WantedBy=paths.target"
done
S="${U}/sync-config.service"
grep -q '^Type=oneshot$' "${S}" || fail "service no es oneshot"
grep -q '^ExecStart=%h/.local/bin/sync-config-watch$' "${S}" || fail "ExecStart incorrecto"
grep -q '^StartLimitIntervalSec=0$' "${S}" || fail "sin StartLimitIntervalSec=0 (ráfaga de stow)"
if grep -q '^\[Install\]' "${S}"; then fail "el service no se habilita, lo dispara el .path"; fi
if command -v systemd-analyze >/dev/null 2>&1; then
  V="${TMP}/verify"; mkdir -p "${V}/home/.local/bin"
  cp "${U}"/sync-config* "${V}/"
  : >"${V}/home/.local/bin/sync-config-watch"; chmod +x "${V}/home/.local/bin/sync-config-watch"
  out="$(HOME="${V}/home" systemd-analyze --user verify "${V}"/sync-config*.path "${V}/sync-config.service" 2>&1)" || true
  if grep -Ei 'unknown (key|section)|bad (unit|setting)|invalid|failed to' <<<"${out}"; then
    fail "systemd-analyze verify"
  fi
fi
echo "ok: unidades"

# --- paso del instalador ---
source "${ROOT_DIR}/scripts/lib/common.sh"
source "${ROOT_DIR}/scripts/modules/sync-config-watcher.sh"
FAKEBIN="${TMP}/fakebin"; mkdir -p "${FAKEBIN}"
cat >"${FAKEBIN}/systemctl" <<'SH'
#!/usr/bin/env bash
echo "$*" >>"${CALLS}"
[[ "$*" == *"is-enabled"* ]] && exit "${ENABLED:-1}"
exit 0
SH
chmod +x "${FAKEBIN}/systemctl"
export CALLS="${TMP}/calls" HOME="${H}"
run() { : >"${CALLS}"; PATH="${FAKEBIN}:${PATH}" ensure_sync_config_watcher >/dev/null; }
OS=ubuntu; run
[[ ! -s "${CALLS}" ]] || fail "tocó systemd fuera de Omarchy"
OS=omarchy; ENABLED=1 run
grep -qx -- '--user daemon-reload' "${CALLS}" || fail "falta daemon-reload"
grep -qx -- '--user enable --now sync-config-omarchy.path sync-config-hypr.path' "${CALLS}" \
  || fail "no habilita las .path"
ENABLED=0 run
if grep -q 'enable --now' "${CALLS}"; then fail "no es idempotente (reactivó)"; fi
echo "ok: instalador"
