#!/usr/bin/env bash
set -euo pipefail

# Deja teamclaude (proxy de failover personal -> ccw) listo en esta máquina.
# INTERACTIVO (logins OAuth en el navegador), por eso no lo corre el bootstrap:
# ejecútalo a mano tras el bootstrap. Idempotente. Ver docs/claude-code.md.

log() { echo "[teamclaude] $*"; }
exists() { command -v "$1" >/dev/null 2>&1; }

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

# Logins nuevos por máquina (no copiar tokens: dos procesos que refrescan el mismo
# refresh token se invalidan). Nunca `callback login` ni `alias --install`.
[[ "$(count_accounts personal)" -gt 0 ]] || { log "Login de la cuenta personal (se abre el navegador)…"; teamclaude login --name personal; }
[[ "$(count_accounts work)" -gt 0 ]] || { log "Login de ccw, la cuenta de empresa (se abre el navegador)…"; teamclaude login --name ccw; }

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
