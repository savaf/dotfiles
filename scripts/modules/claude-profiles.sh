#!/usr/bin/env bash
# Perfiles extra de Claude Code (config dirs aparte para otras cuentas). El
# perfil por defecto es ~/.claude y lo enlaza stow; estos replican la misma
# config compartida vía symlink. Ver docs/claude-code.md.
CLAUDE_PROFILES=(work)

link_claude_profiles() {
  local p dir agent
  for p in "${CLAUDE_PROFILES[@]}"; do
    dir="${HOME}/.claude-${p}"
    log "Enlazando config compartida de Claude en ${dir}…"
    mkdir -p "${dir}/agents"
    ln -sfn "${ROOT_DIR}/claude/.claude/settings.json" "${dir}/settings.json"
    ln -sfn "${ROOT_DIR}/claude/.claude/CLAUDE.md" "${dir}/CLAUDE.md"
    for agent in "${ROOT_DIR}"/claude/.claude/agents/*.md; do
      [[ -e "${agent}" ]] || continue
      ln -sfn "${agent}" "${dir}/agents/$(basename "${agent}")"
    done
    # Las skills reales viven en el perfil por defecto (ahí las instala
    # `npx skills add -g`); los perfiles extra las comparten por symlink.
    if [[ -d "${dir}/skills" && ! -L "${dir}/skills" ]]; then
      log "AVISO: ${dir}/skills es un directorio real; muévelo a ~/.claude/skills y re-ejecuta."
    else
      ln -sfn "${HOME}/.claude/skills" "${dir}/skills"
    fi
  done
}
