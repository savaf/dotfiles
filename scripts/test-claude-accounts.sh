#!/usr/bin/env bash
set -euo pipefail

# Cuentas de Claude sobre el swap de Omarchy: `ccw` abre siempre la cuenta `urbn`, en zsh y bash.
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
