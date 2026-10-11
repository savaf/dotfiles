#!/usr/bin/env bash
# statusLine para Claude Code. Recibe por stdin el JSON de estado de la sesión e imprime:
#   <dir> ⎇ <rama>[✱sucio][↑ahead↓behind] · ctx <pct>%<barra> · $<coste> · +add/-del · <modelo> <effort>[ <output_style>] · [cuenta del proxy] 5h <pct>%↻<hora> 7d <pct>%
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
rl_reset="$(get '.rate_limits.five_hour.resets_at')"
rl7_pct="$(get '.rate_limits.seven_day.used_percentage')"
rl7_pct="${rl7_pct%%.*}"
effort="$(get '.effort.level')"

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
  if (( ctx_pct >= 75 )); then ctx_color="${red}"
  elif (( ctx_pct >= 50 )); then ctx_color="${yellow}"
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
[[ -n "${effort}" ]] && out="${out} ${grey}${effort}${reset}"
[[ -n "${style}" && "${style}" != "default" ]] && out="${out} ${grey}[${style}]${reset}"

# --- proxy de failover (teamclaude): cuenta activa y su cuota; sin proxy, "directo" ---
# Con proxy, la cuota de la cuenta activa sale del propio proxy (el JSON de la sesión no
# sabe qué cuenta sirvió cada petición).
base="${ANTHROPIC_BASE_URL:-}"
if [[ "${base}" =~ :345[67]/?$ ]]; then
  status="$(curl -fs -m 1 "${base%/}/teamclaude/status" 2>/dev/null)"
  if [[ -n "${status}" ]]; then
    IFS=$'\t' read -r acct p5 p7 < <(printf '%s' "${status}" | jq -r '
      .currentAccount as $c | (.accounts[] | select(.name == $c)) |
      [.name, ((.quota.unified5h // empty) * 100 | floor), ((.quota.unified7d // empty) * 100 | floor)] | @tsv' 2>/dev/null)
    if [[ -n "${acct:-}" ]]; then
      case "${acct#*@}" in
        gmail.com) acct="personal" ;;
        urbn.com) acct="ccw" ;;
        *) acct="${acct%%@*}" ;;
      esac
      out="${out} ${grey}·${reset} ${yellow}⇄ ${acct}${reset}"
      [[ -n "${p5:-}" ]] && rl_pct="${p5}"
      [[ -n "${p7:-}" ]] && rl7_pct="${p7}"
    fi
  else
    out="${out} ${grey}· proxy off${reset}"
  fi
else
  out="${out} ${grey}· directo${reset}"
fi

# --- límites del plan (solo si se exponen): 5h con hora de reinicio, y semanal ---
if [[ -n "${rl_pct}" ]]; then
  seg="5h ${rl_pct}%"
  if [[ -n "${rl_reset}" ]]; then
    hhmm="$(date -d "@${rl_reset}" +%H:%M 2>/dev/null || date -r "${rl_reset}" +%H:%M 2>/dev/null)"
    [[ -n "${hhmm}" ]] && seg="${seg}↻${hhmm}"
  fi
  out="${out} ${grey}${seg}${reset}"
fi
[[ -n "${rl7_pct}" ]] && out="${out} ${grey}7d ${rl7_pct}%${reset}"

printf '%b\n' "${out}"
