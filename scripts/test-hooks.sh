#!/usr/bin/env bash
set -euo pipefail

# Corre los tests de los hooks de Claude Code. Sin frameworks: cada test es un script de node.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="${ROOT_DIR}/claude/.claude/hooks"

for t in git-guardrails guard-protected-branch decision-shadow; do
  echo "== ${t}"
  node "${HOOKS_DIR}/${t}.test.mjs"
done
