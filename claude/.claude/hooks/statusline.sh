#!/usr/bin/env bash
# statusLine para Claude Code. Recibe por stdin el JSON de estado de la sesión e
# imprime una línea: <dir> ⎇ <rama> · <modelo>.
#
# El modelo va al final y en color porque es el dato que esta línea existe para
# recordar: sin él la sesión se queda en Opus por inercia (ver docs/claude-code.md).
#
# jq no está en packages/*.txt, así que no se puede asumir. Con jq se parsea bien;
# sin él, grep sobre el JSON compacto basta para dos campos planos.
set -uo pipefail

input="$(cat)"

field() { # field <clave>
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "${input}" | jq -r "${2} // empty" 2>/dev/null
  else
    printf '%s' "${input}" | grep -o "\"${1}\":\"[^\"]*\"" | head -1 | cut -d'"' -f4
  fi
}

model="$(field display_name '.model.display_name')"
dir="$(field current_dir '.workspace.current_dir')"

[[ -z "${dir}" ]] && dir="${PWD}"
[[ -z "${model}" ]] && model="?"

branch="$(git -C "${dir}" branch --show-current 2>/dev/null)"

# 90=gris, 33=amarillo (rama), 36=cian (modelo).
out="\033[90m$(basename "${dir}")\033[0m"
[[ -n "${branch}" ]] && out="${out} \033[33m⎇ ${branch}\033[0m"
out="${out} \033[90m·\033[0m \033[36m${model}\033[0m"

printf '%b\n' "${out}"
