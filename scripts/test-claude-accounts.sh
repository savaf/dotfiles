#!/usr/bin/env bash
set -euo pipefail

# Cuentas de Claude sobre el swap de Omarchy: `ccw` abre siempre la cuenta `urbn`, en zsh y bash,
# la statusline dice qué cuenta usa la sesión y el instalador registra el MCP en la primaria.
# Omarchy y claude son stubs, con PATH cerrado y HOME temporal: no toca cuentas reales.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
BIN="${TMP}/bin"
LOG="${TMP}/claude.log"
mkdir -p "${BIN}" "${TMP}/home"
# PATH cerrado: en un equipo Omarchy el comando real vive en /usr/bin.
ln -s "$(command -v awk)" "${BIN}/awk"

fail() { echo "FAIL: $*"; exit 1; }

cat >"${BIN}/claude" <<EOF
#!/bin/sh
{ echo "home=\${CLAUDE_CONFIG_DIR-}"; for a in "\$@"; do echo "arg=\$a"; done; } >"${LOG}"
exit 7
EOF
chmod +x "${BIN}/claude"

# $1 = líneas `id<TAB>home<TAB>activa` que devuelve `homes claude`
stub_omarchy() {
  cat >"${BIN}/omarchy-agent-account-state" <<EOF
#!/bin/sh
[ "\$*" = "homes claude" ] || exit 1
printf '$1'
EOF
  chmod +x "${BIN}/omarchy-agent-account-state"
}

# run <shell> [args de ccw...]: deja la salida en OUT y el código en RC.
run() {
  local sh="$1" file
  shift
  case "${sh}" in
    bash) file="${REPO}/bash/.config/bash/functions.sh"; set -- --norc --noprofile -c "${SNIPPET}" _ "${BIN}" "${file}" "$@" ;;
    zsh)  file="${REPO}/zsh/.config/zsh/functions.zsh";  set -- -f -c "${SNIPPET}" _ "${BIN}" "${file}" "$@" ;;
  esac
  rm -f "${LOG}"
  RC=0
  OUT="$(HOME="${TMP}/home" CLAUDE_CONFIG_DIR=/heredado "$(command -v "${sh}")" "$@" 2>&1)" || RC=$?
}
# shellcheck disable=SC2016 # lo expande el shell hijo
SNIPPET='PATH="$1"; source "$2"; shift 2; ccw "$@"; rc=$?; echo "despues=$CLAUDE_CONFIG_DIR"; exit $rc'

for sh in bash zsh; do
  if ! command -v "${sh}" >/dev/null 2>&1; then
    echo "AVISO: sin ${sh}; no se prueba ccw en ${sh}"
    continue
  fi

  # 1. usa el home de urbn aunque la activa sea otra, y pasa los argumentos tal cual
  stub_omarchy 'main\t/h/.claude\t1\nurbn-2\t/h/otra\t0\nurbn\t/h/cuentas con espacio/urbn\t0\n'
  run "${sh}" --model opus 'dos palabras'
  [[ -f "${LOG}" ]] || fail "${sh}: no lanzó claude: ${OUT}"
  [[ "$(<"${LOG}")" == $'home=/h/cuentas con espacio/urbn\narg=--model\narg=opus\narg=dos palabras' ]] \
    || fail "${sh}: home o argumentos incorrectos: $(<"${LOG}")"
  [[ ${RC} -eq 7 ]] || fail "${sh}: no devuelve el código de claude (${RC})"
  [[ "${OUT}" == *"despues=/heredado"* ]] || fail "${sh}: ccw dejó CLAUDE_CONFIG_DIR cambiado: ${OUT}"

  # 2. sin cuenta urbn: mensaje claro y no abre claude
  stub_omarchy 'main\t/h/.claude\t1\n'
  run "${sh}"
  [[ ${RC} -ne 0 && ! -e "${LOG}" ]] || fail "${sh}: sin urbn debía fallar sin abrir claude"
  [[ "${OUT}" == *"ccw:"*"urbn"* ]] || fail "${sh}: sin urbn no explica el fallo: ${OUT}"

  # 3. sin Omarchy: igual
  rm "${BIN}/omarchy-agent-account-state"
  run "${sh}"
  [[ ${RC} -ne 0 && ! -e "${LOG}" ]] || fail "${sh}: sin Omarchy debía fallar sin abrir claude"
  [[ "${OUT}" == *"ccw:"*"Omarchy"* ]] || fail "${sh}: sin Omarchy no explica el fallo: ${OUT}"

  echo "OK: ccw (${sh})"
done

# --- statusline: etiqueta de la cuenta de la sesión ---
STATE="${TMP}/state"
URBN="${TMP}/cuentas con espacio/urbn"
INPUT="{\"workspace\":{\"current_dir\":\"${TMP}\"},\"model\":{\"display_name\":\"Opus\"},\"rate_limits\":{\"five_hour\":{\"used_percentage\":12},\"seven_day\":{\"used_percentage\":34}}}"

# registry <state home>: la activa es urbn a propósito; la sesión no depende de ella
registry() {
  mkdir -p "$1/omarchy/agents/accounts"
  cat >"$1/omarchy/agents/accounts/claude.json" <<EOF
{"active":"urbn","accounts":[
  {"id":"main","label":"Personal","home":"","primary":true},
  {"id":"urbn","label":"URBN","home":"${URBN}","primary":false}
]}
EOF
}

# status [args de env...]: deja en OUT la línea sin colores; falla si hay error o stderr
status() {
  OUT="$(printf '%s' "${INPUT}" \
    | env -u CLAUDE_CONFIG_DIR HOME="${TMP}/home" XDG_STATE_HOME="${STATE}" \
      env "$@" bash "${REPO}/claude/.claude/hooks/statusline.sh" 2>"${TMP}/err")" \
    || fail "statusline: salió con error"
  [[ ! -s "${TMP}/err" ]] || fail "statusline: escribió en stderr: $(<"${TMP}/err")"
  OUT="$(printf '%s' "${OUT}" | sed $'s/\033\\[[0-9;]*m//g')"
}
BASE="$(basename "${TMP}") · Opus"
LIMITS="5h 12% 7d 34%"

# 4. sin registro (fuera de Omarchy): no muestra cuenta, y los límites siguen
status
[[ "${OUT}" == "${BASE} ${LIMITS}" ]] || fail "statusline sin registro: ${OUT}"

registry "${STATE}"
# 5. sin CLAUDE_CONFIG_DIR, vacío o apuntando a ~/.claude: la primaria
status
[[ "${OUT}" == "${BASE} · Personal ${LIMITS}" ]] || fail "statusline primaria: ${OUT}"
for cfg in "" "${TMP}/home/.claude"; do
  status "CLAUDE_CONFIG_DIR=${cfg}"
  [[ "${OUT}" == "${BASE} · Personal ${LIMITS}" ]] || fail "statusline primaria (${cfg:-vacío}): ${OUT}"
done

# 6. con el home de una cuenta añadida: su etiqueta
status "CLAUDE_CONFIG_DIR=${URBN}"
[[ "${OUT}" == "${BASE} · URBN ${LIMITS}" ]] || fail "statusline urbn: ${OUT}"

# 7. home que no está en el registro: nada
status "CLAUDE_CONFIG_DIR=${TMP}/otra"
[[ "${OUT}" == "${BASE} ${LIMITS}" ]] || fail "statusline sin coincidencia: ${OUT}"

# 8. sin XDG_STATE_HOME usa ~/.local/state
registry "${TMP}/home/.local/state"
status -u XDG_STATE_HOME
[[ "${OUT}" == "${BASE} · Personal ${LIMITS}" ]] || fail "statusline sin XDG_STATE_HOME: ${OUT}"

# 9. registro corrupto: no muestra cuenta ni errores
echo '{roto' >"${STATE}/omarchy/agents/accounts/claude.json"
status
[[ "${OUT}" == "${BASE} ${LIMITS}" ]] || fail "statusline con registro corrupto: ${OUT}"

echo "OK: statusline"

# --- install-claude-skills.sh: el MCP se registra en la cuenta primaria ---
# Con el manifiesto vacío solo queda register_mcp. El stub anota el entorno que ve claude: el wrapper
# de Omarchy elige la cuenta activa salvo que exista OMARCHY_AGENT_CLAUDE_HOME (vacía = primaria).
cat >"${BIN}/claude" <<EOF
#!/bin/sh
echo "\$2 config=\${CLAUDE_CONFIG_DIR-unset} pin=\${OMARCHY_AGENT_CLAUDE_HOME-unset}" >>"${LOG}"
[ "\$2" != get ]
EOF
rm -f "${LOG}"
OUT="$(HOME="${TMP}/home" PATH="${BIN}:${PATH}" SKILLS_LIST=/dev/null CLAUDE_CONFIG_DIR=/heredado \
  OMARCHY_AGENT_CLAUDE_HOME=/otra bash "${REPO}/scripts/install-claude-skills.sh" 2>&1)" \
  || fail "register_mcp: el instalador falló: ${OUT}"
[[ "$(<"${LOG}")" == $'get config=unset pin=\nadd config=unset pin=' ]] \
  || fail "register_mcp: no fija la cuenta primaria: $(<"${LOG}")"

echo "OK: register_mcp"
