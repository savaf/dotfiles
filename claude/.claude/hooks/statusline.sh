#!/usr/bin/env bash
# statusLine para Claude Code. Recibe por stdin el JSON de estado de la sesión e imprime:
#   <dir> ⎇ <rama>[✱sucio][↑ahead↓behind] · ctx <pct>%<barra> · $<coste> · +add/-del · <modelo>[ <output_style>] [5h <pct>%]
#
# El modelo va al final y en color porque es el dato que esta línea existe para
# recordar: sin él la sesión se queda en Opus por inercia (ver docs/claude-code.md).
# El resto de campos existen para no tener que pedir manualmente /context o /usage:
# uso de la ventana de contexto y coste ya vienen resueltos en el JSON de entrada.
#
# jq es paquete base en las cuatro plataformas de este repo (packages/*.txt), así que
# se asume disponible sin fallback a grep.
set -uo pipefail

input="$(cat)"
get() { printf '%s' "${input}" | jq -r "${1} // empty" 2>/dev/null; }

dir="$(get '.workspace.current_dir')"
[[ -z "${dir}" ]] && dir="${PWD}"
model="$(get '.model.display_name')"
[[ -z "${model}" ]] && model="?"
style="$(get '.output_style.name')"
cost="$(get '.cost.total_cost_usd')"
added="$(get '.cost.total_lines_added')"
removed="$(get '.cost.total_lines_removed')"
ctx_pct="$(get '.context_window.used_percentage')"
ctx_pct="${ctx_pct%%.*}"
rl_pct="$(get '.rate_limits.five_hour.used_percentage')"
rl_pct="${rl_pct%%.*}"

# 90=gris, 33=amarillo (rama), 36=cian (modelo), 32=verde, 31=rojo.
grey=$'\033[90m'; reset=$'\033[0m'
yellow=$'\033[33m'; cyan=$'\033[36m'; green=$'\033[32m'; red=$'\033[31m'

out="${grey}$(basename "${dir}")${reset}"

# --- git: rama, cambios sin commitear, divergencia con upstream ---
branch="$(git -C "${dir}" branch --show-current 2>/dev/null)"
if [[ -n "${branch}" ]]; then
  seg="⎇ ${branch}"
  changes="$(git -C "${dir}" status --porcelain 2>/dev/null | wc -l)"
  (( changes > 0 )) && seg="${seg} ${red}✱${changes}${yellow}"
  counts="$(git -C "${dir}" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)"
  if [[ -n "${counts}" ]]; then
    behind="${counts%%$'\t'*}"; ahead="${counts##*$'\t'}"
    (( ahead > 0 )) && seg="${seg} ↑${ahead}"
    (( behind > 0 )) && seg="${seg} ↓${behind}"
  fi
  out="${out} ${yellow}${seg}${reset}"
fi

# --- ventana de contexto: barra de 5 bloques + color por umbral ---
if [[ -n "${ctx_pct}" ]]; then
  if (( ctx_pct >= 90 )); then ctx_color="${red}"
  elif (( ctx_pct >= 70 )); then ctx_color="${yellow}"
  else ctx_color="${green}"
  fi
  filled=$(( ctx_pct / 20 ))
  (( filled > 5 )) && filled=5
  bar=""
  for ((i = 0; i < 5; i++)); do
    if (( i < filled )); then bar="${bar}▰"; else bar="${bar}▱"; fi
  done
  out="${out} ${grey}·${reset} ${ctx_color}ctx ${ctx_pct}%${reset} ${grey}${bar}${reset}"
fi

# --- coste de la sesión ---
if [[ -n "${cost}" ]] && awk -v c="${cost}" 'BEGIN{exit !(c>0)}'; then
  out="${out} ${grey}·${reset} ${grey}\$$(printf '%.2f' "${cost}")${reset}"
fi

# --- líneas tocadas en la sesión ---
if [[ -n "${added}" && -n "${removed}" ]] && (( added > 0 || removed > 0 )); then
  out="${out} ${grey}·${reset} ${green}+${added}${reset}${grey}/${reset}${red}-${removed}${reset}"
fi

# --- modelo (siempre visible) + output style si no es el default ---
out="${out} ${grey}·${reset} ${cyan}${model}${reset}"
[[ -n "${style}" && "${style}" != "default" ]] && out="${out} ${grey}[${style}]${reset}"

# --- % consumido de la ventana de 5h (solo si el plan la expone) ---
[[ -n "${rl_pct}" ]] && out="${out} ${grey}5h ${rl_pct}%${reset}"

printf '%b\n' "${out}"
