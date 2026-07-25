#!/usr/bin/env bash
set -euo pipefail

# Installs Claude Code skills listed in packages/claude-skills.txt (user-level,
# ~/.claude/skills) and registers the context7 MCP server. Idempotent: already
# installed skills are skipped by the skills CLI itself.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_LIST="${ROOT_DIR}/packages/claude-skills.txt"

log() { echo "[setup] $*"; }
exists() { command -v "$1" >/dev/null 2>&1; }

install_skills() {
  if ! exists npx; then
    log "npx not available; skipping Claude Code skills."
    return 0
  fi
  local repo
  while IFS= read -r repo; do
    [[ "${repo}" =~ ^[[:space:]]*(#|$) ]] && continue
    log "Installing skill(s) from ${repo}…"
    # -g: user-level; -a: only Claude Code; -s '*': all skills in the repo; -y: no prompts
    npx -y skills add "${repo}" -g -a claude-code -s '*' -y || log "Failed: ${repo} (continuing)."
  done < "${SKILLS_LIST}"
}

register_mcp() {
  if ! exists claude; then
    log "claude CLI not available; skipping MCP registration."
    return 0
  fi
  if claude mcp get context7 >/dev/null 2>&1; then
    log "MCP context7 already registered."
  else
    log "Registering MCP context7 (user scope)…"
    claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp \
      || log "Failed to register context7 (continuing)."
  fi
}

install_skills
register_mcp
log "Claude Code skills/MCP done."
