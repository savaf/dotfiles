#!/usr/bin/env bash
# Sube las versiones fijadas del repo a la última publicada. Lo corre el workflow
# .github/workflows/update-deps.yml cada semana, que abre un PR con el resultado; también
# se puede correr a mano y revisar el `git diff`.
#
#   scripts/update-deps.sh tools    herramientas de mise, nvm, llama.cpp (+sha256), Nerd Font,
#                                   CLI `skills` y paquetes npm fijados
#   scripts/update-deps.sh skills   commits de packages/claude-skills.txt (+sha256 de las fijadas
#                                   por tarball). Va en un PR aparte: hay que AUDITARLO.
#
# Solo sube (nunca baja) versiones. Si una fuente falla, avisa y sigue con las demás.
# Escribe un resumen en markdown en ${CHANGES_FILE} (cuerpo del PR): una lista de cambios (con
# ⚠ **major** si salta el componente mayor) y, si alguna fuente falló, una sección "## Avisos".
# Los avisos no hacen fallar el job. Test: scripts/test-update-deps.sh.
# Env para tests: DEPS_ROOT (raíz que edita) y DEPS_STUBS (archivo que se sourcea al final
# para sustituir las funciones latest_* / head_commit / sha256_url / skill_tree_hash).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DEPS_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
CHANGES_FILE="${CHANGES_FILE:-${ROOT}/.deps-changes.md}"
# shellcheck source=lib/third-party.sh
. "${SCRIPT_DIR}/lib/third-party.sh"

WARNINGS=()
# Los avisos van a stderr y, al final, a la sección "## Avisos" de CHANGES_FILE (no hacen fallar).
warn() { echo "[deps] AVISO: $*" >&2; WARNINGS+=("$*"); }
note() { echo "[deps] $*" >&2; echo "- $*" >> "${CHANGES_FILE}"; }
# note + marca ⚠ major si cambia el componente mayor de la versión (ignora el prefijo v). <viejo> <nuevo> <texto>
note_bump() {
  local a="${1#v}" b="${2#v}"
  [[ "${a%%.*}" != "${b%%.*}" ]] && set -- "$1" "$2" "$3 ⚠ **major**"
  note "$3"
}

# ¿$2 es estrictamente mayor que $1? (sort -V; los prefijos v/b no afectan al orden)
# Las prereleases (-rc, -beta, nightly…) nunca cuentan como versión nueva.
newer() {
  [[ -n "$2" && "$1" != "$2" ]] || return 1
  [[ "$2" =~ (rc|alpha|beta|pre|dev|nightly) ]] && return 1
  [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" == "$2" ]]
}

# Sustituye literalmente $2 por $3 en el archivo $1 (sin regex, todas las apariciones).
replace() {
  local f="$1" old="$2" new="$3" s
  s="$(<"${f}")"; printf '%s\n' "${s//"${old}"/"${new}"}" > "${f}"
}

# --- Consultas (sustituibles en tests) ------------------------------------------------------
latest_github_release() { gh api "repos/$1/releases/latest" --jq .tag_name 2>/dev/null; }
# llama.cpp publica sus builds `bNNNNN` marcadas como prerelease; "latest" es otra cosa (v0.x).
latest_llama_build() {
  gh api "repos/ggml-org/llama.cpp/releases?per_page=20" \
    --jq '[.[].tag_name | select(test("^b[0-9]+$"))][0] // empty' 2>/dev/null
}
latest_npm() { npm view "$1" version 2>/dev/null; }
latest_mise() { mise latest "$1" 2>/dev/null; }
head_commit() { gh api "repos/$1/commits/HEAD" --jq .sha 2>/dev/null; }
# sha256 de una URL; falla (sin imprimir nada) si la descarga falla: nunca el hash de vacío.
sha256_url() {
  local tmp rc=0
  tmp="$(mktemp)" || return 1
  curl -fsSL --retry 2 -o "${tmp}" "$1" && [[ -s "${tmp}" ]] && tp_sha < "${tmp}" || rc=1
  rm -f "${tmp}"
  return "${rc}"
}
# Hash de contenido (tp_hash) de <ruta> dentro del tarball de <owner/repo>@<commit>.
skill_tree_hash() {
  local repo="$1" commit="$2" path="$3" tmp top h=""
  tmp="$(mktemp -d)" || return 1
  if curl -fsSL --retry 2 "https://codeload.github.com/${repo}/tar.gz/${commit}" | tar -xz -C "${tmp}"; then
    top="$(find "${tmp}" -mindepth 1 -maxdepth 1 -type d | head -n1)"
    [[ -e "${top}/${path}" ]] && h="$(tp_hash "${top}/${path}")"
  fi
  rm -rf "${tmp}"
  [[ -n "${h}" ]] && printf '%s\n' "${h}"
}

# --- Actualizadores -------------------------------------------------------------------------
bump_mise() {
  local f="${ROOT}/mise/.config/mise/config.toml" line tool cur new in_tools=0 lines
  local re='^([A-Za-z0-9_.:/-]+)[[:space:]]*=[[:space:]]*(\{[^}]*version[[:space:]]*=[[:space:]]*)?"([^"]+)"'
  [[ -f "${f}" ]] || return 0
  # Se lee entero antes: replace() reescribe el archivo dentro del bucle.
  mapfile -t lines < "${f}"
  for line in "${lines[@]}"; do
    [[ "${line}" =~ ^\[(.*)\] ]] && { [[ "${BASH_REMATCH[1]}" == tools ]] && in_tools=1 || in_tools=0; continue; }
    (( in_tools )) || continue
    # `tool = "1.2.3"` o `tool = { version = "1.2.3", … }`
    [[ "${line}" =~ ${re} ]] || continue
    tool="${BASH_REMATCH[1]}"; cur="${BASH_REMATCH[3]}"
    new="$(latest_mise "${tool}")" || { warn "mise latest ${tool} falló"; continue; }
    newer "${cur}" "${new}" || continue
    replace "${f}" "${line}" "${line/\"${cur}\"/\"${new}\"}"
    note_bump "${cur}" "${new}" "mise \`${tool}\`: ${cur} → ${new}"
  done
}

# bump_github_tag <archivo> <owner/repo> <regex con un grupo = tag actual> <plantilla con %s>
bump_github_tag() {
  local f="$1" repo="$2" re="$3" tpl="$4" cur new
  [[ -f "${f}" ]] || return 0
  [[ "$(<"${f}")" =~ ${re} ]] || { warn "no encuentro la versión de ${repo} en ${f#"${ROOT}"/}"; return 0; }
  cur="${BASH_REMATCH[1]}"
  new="$(latest_github_release "${repo}")" || { warn "release de ${repo} no disponible"; return 0; }
  [[ "${new}" =~ ^v[0-9]+(\.[0-9]+)*$ ]] || { warn "tag de ${repo} inesperado: '${new}'"; return 0; }
  newer "${cur}" "${new}" || return 0
  # shellcheck disable=SC2059 # la plantilla es nuestra
  replace "${f}" "$(printf "${tpl}" "${cur}")" "$(printf "${tpl}" "${new}")"
  note_bump "${cur}" "${new}" "${repo}: ${cur} → ${new} (https://github.com/${repo}/releases/tag/${new})"
}

bump_nvm() {
  bump_github_tag "${ROOT}/scripts/modules/node.sh" nvm-sh/nvm \
    'nvm-sh/nvm/(v[0-9.]+)/install\.sh' 'nvm-sh/nvm/%s/install.sh'
}

bump_nerd_font() {
  bump_github_tag "${ROOT}/scripts/install-packages.sh" ryanoasis/nerd-fonts \
    'NF_VERSION="(v[0-9.]+)"' 'NF_VERSION="%s"'
}

# llama.cpp: el tag y los sha256 de los dos tarballs CUDA van juntos; o todo o nada.
bump_llama() {
  local f="${ROOT}/scripts/modules/llama.sh" repo=ggml-org/llama.cpp cur new t url
  local -A old_sha new_sha
  [[ -f "${f}" ]] || return 0
  [[ "$(<"${f}")" =~ LLAMA_CPP_VERSION=\"(b[0-9]+)\" ]] || { warn "no encuentro LLAMA_CPP_VERSION"; return 0; }
  cur="${BASH_REMATCH[1]}"
  new="$(latest_llama_build)" || { warn "builds de ${repo} no disponibles"; return 0; }
  [[ "${new}" =~ ^b[0-9]+$ ]] || { warn "tag de ${repo} inesperado: '${new}'"; return 0; }
  newer "${cur}" "${new}" || return 0
  for t in llama cudart-llama; do
    [[ "$(<"${f}")" =~ \[${t}\]=([0-9a-f]{64}) ]] || { warn "no encuentro el sha256 de ${t}"; return 0; }
    old_sha[${t}]="${BASH_REMATCH[1]}"
    url="https://github.com/${repo}/releases/download/${new}/${t}-${new}-bin-ubuntu-cuda-12.8-x64.tar.gz"
    new_sha[${t}]="$(sha256_url "${url}")" || new_sha[${t}]=""
    [[ "${new_sha[${t}]}" =~ ^[0-9a-f]{64}$ ]] \
      || { warn "llama.cpp ${new}: no se pudo bajar ${url}; no se toca"; return 0; }
  done
  replace "${f}" "LLAMA_CPP_VERSION=\"${cur}\"" "LLAMA_CPP_VERSION=\"${new}\""
  for t in llama cudart-llama; do replace "${f}" "${old_sha[${t}]}" "${new_sha[${t}]}"; done
  note "${repo}: ${cur} → ${new}, sha256 recalculados (https://github.com/${repo}/releases/tag/${new})"
}

# Paquetes npm fijados como `nombre@versión` (CLI `skills` y globals con versión).
bump_npm_pin() {
  local f="$1" pkg="$2" cur new
  [[ -f "${f}" ]] || return 0
  [[ "$(<"${f}")" =~ ${pkg//./\\.}@([0-9][0-9A-Za-z.-]*) ]] || return 0
  cur="${BASH_REMATCH[1]}"
  new="$(latest_npm "${pkg}")" || { warn "npm view ${pkg} falló"; return 0; }
  newer "${cur}" "${new}" || return 0
  replace "${f}" "${pkg}@${cur}" "${pkg}@${new}"
  note_bump "${cur}" "${new}" "npm \`${pkg}\`: ${cur} → ${new}"
}

bump_npm_pins() {
  bump_npm_pin "${ROOT}/scripts/install-claude-skills.sh" skills
  local f="${ROOT}/packages/global-node-packages.txt" line lines re='^(@?[^@[:space:]#]+)@[0-9]'
  [[ -f "${f}" ]] || return 0
  mapfile -t lines < "${f}"
  for line in "${lines[@]}"; do
    [[ "${line}" =~ ${re} ]] && bump_npm_pin "${f}" "${BASH_REMATCH[1]}"
  done
}

# Skills: cada línea activa `owner/repo#<sha> …` pasa al HEAD de la rama por defecto. Las
# fijadas por tarball (`… <skill> <ruta> <sha256>`) recalculan el hash; si no se puede, no se tocan.
bump_skills() {
  local f="${ROOT}/packages/claude-skills.txt" repo_ref only path sha repo cur new h line lines
  [[ -f "${f}" ]] || return 0
  mapfile -t lines < "${f}"
  for line in "${lines[@]}"; do
    read -r repo_ref only path sha _ <<< "${line}"
    [[ "${repo_ref}" =~ ^([^#[:space:]]+/[^#[:space:]]+)#([0-9a-f]{40})$ ]] || continue
    repo="${BASH_REMATCH[1]}"; cur="${BASH_REMATCH[2]}"
    new="$(head_commit "${repo}")" || { warn "HEAD de ${repo} no disponible"; continue; }
    [[ "${new}" =~ ^[0-9a-f]{40}$ && "${new}" != "${cur}" ]] || continue
    if [[ -n "${path}" ]]; then
      h="$(skill_tree_hash "${repo}" "${new}" "${path}")"
      [[ "${h}" =~ ^[0-9a-f]{64}$ ]] || { warn "${repo}@${new:0:8}: no pude calcular el hash de ${path}; no se toca"; continue; }
      replace "${f}" "${line}" "${line/${cur}/${new}}"
      replace "${f}" "${sha}" "${h}"
    else
      replace "${f}" "${line}" "${line/${cur}/${new}}"
    fi
    note "[ ] \`${repo}\`${only:+ (${only})}: ${cur:0:8} → ${new:0:8} — auditar: https://github.com/${repo}/compare/${cur}...${new}"
  done
}

main() {
  local mode="${1:-}"
  : > "${CHANGES_FILE}"
  case "${mode}" in
    tools) bump_mise; bump_nvm; bump_llama; bump_nerd_font; bump_npm_pins ;;
    skills) bump_skills ;;
    *) echo "uso: $0 tools|skills" >&2; return 2 ;;
  esac
  if (( ${#WARNINGS[@]} )); then
    [[ -s "${CHANGES_FILE}" ]] && echo >> "${CHANGES_FILE}"
    { echo "## Avisos"; echo; printf -- '- %s\n' "${WARNINGS[@]}"; } >> "${CHANGES_FILE}"
  else
    [[ -s "${CHANGES_FILE}" ]] || echo "[deps] Nada que actualizar (${mode})." >&2
  fi
}

# shellcheck disable=SC1090
[[ -n "${DEPS_STUBS:-}" ]] && . "${DEPS_STUBS}"
main "$@"
