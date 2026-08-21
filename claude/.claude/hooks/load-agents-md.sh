#!/usr/bin/env bash
set -eo pipefail

# SessionStart: inyecta el AGENTS.md del proyecto cuando Claude Code no lo
# cargaria solo. Claude Code auto-carga CLAUDE.md; AGENTS.md es el estandar
# entre herramientas (Codex, Cursor, Gemini) y muchos repos solo tienen ese.
#
# Se salta cuando:
#   - no hay AGENTS.md
#   - existe CLAUDE.md (ya se carga; si quiere AGENTS.md, que lo referencie)
#   - el proyecto define su propio hook SessionStart (ya gestiona su contexto)

dir="${CLAUDE_PROJECT_DIR:-$PWD}"

agents_file="${dir}/AGENTS.md"
[ -f "${agents_file}" ] || exit 0
[ -f "${dir}/CLAUDE.md" ] && exit 0

# Un SessionStart propio significa que el proyecto ya inyecta lo que necesita.
for settings in "${dir}/.claude/settings.json" "${dir}/.claude/settings.local.json"; do
  [ -f "${settings}" ] || continue
  if command -v jq >/dev/null 2>&1; then
    if jq -e '.hooks.SessionStart' "${settings}" >/dev/null 2>&1; then
      exit 0
    fi
  elif grep -q 'SessionStart' "${settings}"; then
    exit 0
  fi
done

echo "=== ${agents_file#"${dir}"/} (proyecto) ==="
cat "${agents_file}"
