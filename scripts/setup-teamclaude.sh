#!/usr/bin/env bash
set -euo pipefail

# Deja teamclaude (proxy de failover personal -> ccw) listo en esta máquina.
# INTERACTIVO (logins OAuth en el navegador), por eso no lo corre el bootstrap:
# ejecútalo a mano tras el bootstrap. Idempotente. Ver docs/claude-code.md.

log() { echo "[teamclaude] $*"; }
exists() { command -v "$1" >/dev/null 2>&1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${TEAMCLAUDE_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/teamclaude.json}"

if ! exists teamclaude; then
  log "teamclaude no instalado; corre el bootstrap (packages/global-node-packages.txt)."
  exit 1
fi

# Una versión nueva correría con acceso a los tokens: sin self-update.
export TEAMCLAUDE_DISABLE_AUTOUPDATE=1

# teamclaude renombra las cuentas a su email tras el primer uso, así que se distinguen por
# tipo de organización: enterprise/team = ccw (respaldo), el resto = personal (preferida).
count_accounts() { # $1 = work | personal
  [[ -f "${CONFIG}" ]] || { echo 0; return; }
  node -e 'const c=require(process.argv[1]);const w=a=>/enterprise|team/i.test(a.organizationType||"");
    console.log((c.accounts||[]).filter(a=>(process.argv[2]==="work")===w(a)).length)' "${CONFIG}" "$1"
}

# Cada login abre el navegador en una sesión DISTINTA (Brave: un perfil por cuenta, con sus
# extensiones y passkeys; si no, un perfil limpio de Chrome/Edge): si no, la segunda cuenta se
# abriría con la sesión de claude.ai de la primera. scripts/teamclaude-browser.sh hace de
# `xdg-open`/`open` solo durante el login. Cierra esa ventana al terminar.
login_isolated() { # $1 = nombre de la cuenta
  local acct="$1" shim_dir profile
  if grep -qi microsoft /proc/version 2>/dev/null; then
    profile="$(wslpath "$(cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')")/teamclaude-login-${acct}"
  else
    profile="${XDG_CACHE_HOME:-${HOME}/.cache}/teamclaude-login/${acct}"
  fi
  mkdir -p "${profile}"
  find "${profile}" -mindepth 1 -delete 2>/dev/null || true # perfil limpio en cada login
  shim_dir="$(mktemp -d)"
  ln -s "${SCRIPT_DIR}/teamclaude-browser.sh" "${shim_dir}/xdg-open"
  ln -s "${SCRIPT_DIR}/teamclaude-browser.sh" "${shim_dir}/open"
  log "Login de '${acct}' en una ventana de navegador aislada (perfil limpio)…"
  PATH="${shim_dir}:${PATH}" TC_BROWSER_ACCOUNT="${acct}" TC_BROWSER_PROFILE="${profile}" teamclaude login --name "${acct}" || true
  rm -f "${shim_dir}/xdg-open" "${shim_dir}/open"
  rmdir "${shim_dir}"
}

# Logins nuevos por máquina (no copiar tokens: dos procesos que refrescan el mismo
# refresh token se invalidan). Nunca `callback login` ni `alias --install`.
[[ "$(count_accounts personal)" -gt 0 ]] || login_isolated personal
[[ "$(count_accounts work)" -gt 0 ]] || login_isolated ccw

# Prioridad: personal 0, ccw 1.
node -e 'const c=require(process.argv[1]);for(const a of c.accounts)
  console.log((/enterprise|team/i.test(a.organizationType||"")?1:0)+"\t"+a.name)' "${CONFIG}" |
  while IFS=$'\t' read -r prio name; do teamclaude priority "${name}" "${prio}"; done

# Reactivo (solo cambia al agotarse), modo base-url y sin auto-update.
node -e '
const fs=require("fs"),p=process.argv[1],c=JSON.parse(fs.readFileSync(p));
c.autoUpdate=false;c.switchThreshold=1;c.defaultClientMode="base-url";
fs.writeFileSync(p,JSON.stringify(c,null,2),{mode:0o600});' "${CONFIG}"

if teamclaude service status >/dev/null 2>&1; then
  log "Servicio ya instalado."
else
  log "Instalando el servicio de usuario…"
  teamclaude service install
fi
log "Listo. Abre una terminal nueva: 'claude' pasa por el proxy (:3456); 'teamclaude status' para verlo."
