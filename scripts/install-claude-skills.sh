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
    # stdin a /dev/null: si no, la CLI consume el stdin del bucle y solo se
    # procesa la primera línea del manifiesto.
    npx -y skills add "${repo}" -g -a claude-code -s '*' -y </dev/null \
      || log "Failed: ${repo} (continuing)."
  done < "${SKILLS_LIST}"
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

install_skills
register_mcp
log "Claude Code skills/MCP done."
