#!/usr/bin/env bash
set -euo pipefail

# Installs Claude Code skills listed in packages/claude-skills.txt (user-level,
# ~/.claude/skills) and registers the context7 MCP server. Idempotent: already
# installed skills are skipped by the skills CLI itself.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_LIST="${SKILLS_LIST:-${ROOT_DIR}/packages/claude-skills.txt}"
# Pinned: an unpinned CLI runs whatever is latest on every bootstrap. Bump on purpose, then re-review.
SKILLS_CLI="skills@1.7.6"

# shellcheck source=lib/third-party.sh
. "${ROOT_DIR}/scripts/lib/third-party.sh"

log() { echo "[setup] $*"; }
exists() { command -v "$1" >/dev/null 2>&1; }

install_skills() {
  if ! exists npx; then
    log "npx not available; skipping Claude Code skills."
    return 0
  fi
  local repo only path sha names
  while read -r repo only path sha _; do
    [[ -z "${repo}" || "${repo}" == \#* ]] && continue
    # Con la columna de ruta es una línea de tarball fijado: la instala install_pinned_skills.
    [[ -n "${path}" ]] && continue
    log "Installing skill(s) from ${repo} (${only:-all})…"
    # Manifest line: `owner/repo [skill,skill]`; no second column = every skill in the repo.
    # -g: user-level; -a: only Claude Code; -s: skill names; -y: no prompts
    # stdin a /dev/null: si no, la CLI consume el stdin del bucle y solo se
    # procesa la primera línea del manifiesto.
    IFS=',' read -ra names <<< "${only:-*}"
    npx -y "${SKILLS_CLI}" add "${repo}" -g -a claude-code -s "${names[@]}" -y </dev/null \
      || log "Failed: ${repo} (continuing)."
  done < "${SKILLS_LIST}"
  keep_only_skill_md
}

# Líneas del manifiesto con columnas extra: `owner/repo#<commit> <skill> <ruta-en-el-repo> <sha256>`.
# Se bajan como tarball del commit y se instalan solo si el hash del contenido coincide (la CLI
# instalaría otro directorio, p. ej. el espejo .agents de impeccable). Nunca ejecuta lo descargado.
# Falla (código distinto de 0) si una línea está mal formada o un hash no coincide; las demás siguen.
install_pinned_skills() {
  local repo only path sha extra name commit rc=0 dir
  local root="${HOME}/.claude/skills"
  while read -r repo only path sha extra; do
    [[ -z "${repo}" || "${repo}" == \#* || -z "${path}" ]] && continue
    if [[ -n "${extra}" || ! "${repo}" =~ ^[^#[:space:]]+/[^#[:space:]]+#[0-9a-f]{40}$ \
      || "${only}" == *,* || "${path}" == /* || "${path}" == *..* || ! "${sha}" =~ ^[0-9a-f]{64}$ ]]; then
      log "ERROR línea mal formada en el manifiesto: ${repo} ${only} ${path} ${sha} ${extra}"
      rc=1; continue
    fi
    name="${only}"; commit="${repo#*#}"
    log "Installing ${name} from ${repo%%#*}@${commit:0:8} (tarball verificado)…"
    if ! fetch_skill "${name}" "${repo%%#*}" "${commit}" "${path}" "${sha}" "${root}"; then
      dir="${root}/${name}"
      # Nunca dejar bytes sin verificar: una copia previa que no coincide se elimina.
      if [[ -d "${dir}" && ! -L "${dir}" && "$(tp_hash "${dir}" 2>/dev/null)" != "${sha}" ]]; then
        rm -rf "${dir}"; log "Eliminada la copia previa de ${name}: no coincide con el hash fijado."
      fi
      log "Failed: ${name} (hash o descarga no verificados)."
      rc=1
    fi
  done < "${SKILLS_LIST}"
  return "${rc}"
}

# humanizer vive en la raíz del repo y la CLI copia el repo entero (scripts, workflows,
# manifiestos); la auditoría acepta solo SKILL.md.
SKILL_MD_ONLY=(humanizer)

keep_only_skill_md() {
  local name dir tmp
  for name in "${SKILL_MD_ONLY[@]}"; do
    dir="${HOME}/.claude/skills/${name}"
    [[ -d "${dir}" && ! -L "${dir}" && -s "${dir}/SKILL.md" ]] || continue
    tmp="$(mktemp)"
    cp "${dir}/SKILL.md" "${tmp}"
    find "${dir}" -mindepth 1 -delete
    mv "${tmp}" "${dir}/SKILL.md"
  done
}

# MCP servers live in each profile's own .claude.json, so they can't be
# symlinked — register them once per config dir. "" = default profile
# (~/.claude); the rest mirror CLAUDE_PROFILES in bootstrap.sh.
CLAUDE_PROFILES=("" work)

register_mcp() {
  if ! exists claude; then
    log "claude CLI not available; skipping MCP registration."
    return 0
  fi
  local profile label
  for profile in "${CLAUDE_PROFILES[@]}"; do
    if [[ -n "${profile}" ]]; then
      label="${profile}"
      export CLAUDE_CONFIG_DIR="${HOME}/.claude-${profile}"
    else
      label="default"
      unset CLAUDE_CONFIG_DIR
    fi
    if claude mcp get context7 >/dev/null 2>&1; then
      log "MCP context7 already registered (${label})."
    else
      log "Registering MCP context7 (user scope, ${label})…"
      claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp \
        || log "Failed to register context7 for ${label} (continuing)."
    fi
  done
  unset CLAUDE_CONFIG_DIR
}

# Sin argumentos corre todo; `pinned` corre solo el paso de tarballs verificados.
if [[ "${1:-}" == pinned ]]; then
  install_pinned_skills
  exit $?
fi
rc=0
install_skills
install_pinned_skills || { log "Pinned skills failed (see above)."; rc=1; }
register_mcp
log "Claude Code skills/MCP done."
exit "${rc}"
