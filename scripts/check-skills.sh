#!/usr/bin/env bash
set -uo pipefail

# Readiness de las dependencias de super-board (solo dependencias, no el tablero):
# herramientas, scopes de `gh` y skills en ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills.
# Sale 0 solo si todo lo requerido está. Las skills opcionales solo avisan. Compatible con bash 3.2.

SKILLS_DIR="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}/skills"
TOOLS=(gh jq python3 node npx git bash curl tar)
SCOPES=(project read:project repo)
SCOPES_FIX="gh auth refresh -s project,read:project,repo"
REQUIRED=(tdd diagnosing-bugs implement codebase-design code-review
  domain-modeling ask-matt to-spec to-tickets implement-spec improve-codebase-architecture
  ponytail ponytail-review verification-before-completion testing-strategy pr-security-review impeccable)
OPTIONAL=(resolving-merge-conflicts vitest playwright-best-practices security-audit humanizer)

missing=0
warned=0
ok()   { echo "✓ $*"; }
bad()  { echo "✗ $*"; missing=$((missing + 1)); }
warn() { echo "! $*"; warned=$((warned + 1)); }

have_skill() { [[ -s "${SKILLS_DIR}/$1/SKILL.md" && -r "${SKILLS_DIR}/$1/SKILL.md" ]]; }

echo "== tools"
for t in "${TOOLS[@]}"; do
  if command -v "${t}" >/dev/null 2>&1; then ok "${t}"; else bad "${t} (not found)"; fi
done
if command -v python3 >/dev/null 2>&1; then
  if python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' 2>/dev/null; then
    ok "python3 >= 3.9"
  else
    bad "python3 >= 3.9 (found $(python3 -V 2>&1))"
  fi
fi

echo "== gh scopes"
if command -v gh >/dev/null 2>&1; then
  status="$(gh auth status 2>&1)" && logged=1 || logged=0
  if [[ ${logged} -eq 0 ]]; then
    bad "gh scopes (not logged in; run: gh auth login)"
  else
    line="$(printf '%s\n' "${status}" | grep -i 'token scopes' | head -1)"
    absent=""
    for s in "${SCOPES[@]}"; do
      [[ "${line}" == *"'${s}'"* ]] || absent="${absent} ${s}"
    done
    if [[ -z "${line}" ]]; then
      bad "gh scopes (token scopes not visible; run: ${SCOPES_FIX})"
    elif [[ -n "${absent}" ]]; then
      bad "gh scopes (missing:${absent}; run: ${SCOPES_FIX})"
    else
      ok "gh scopes (${SCOPES[*]})"
    fi
  fi
fi

echo "== required skills (${SKILLS_DIR})"
for s in "${REQUIRED[@]}"; do
  if have_skill "${s}"; then ok "${s}"; else bad "${s} (run scripts/install-claude-skills.sh)"; fi
done

echo "== optional skills"
for s in "${OPTIONAL[@]}"; do
  if have_skill "${s}"; then ok "${s}"; else warn "${s} (optional, not installed)"; fi
done

echo "== summary"
if [[ ${missing} -eq 0 ]]; then
  echo "ready: all required items present (${warned} optional missing)"
  exit 0
fi
echo "not ready: ${missing} required item(s) missing (${warned} optional missing)"
exit 1
