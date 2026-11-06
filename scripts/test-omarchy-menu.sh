#!/usr/bin/env bash
set -euo pipefail

# Comprueba la extensión del menú de Omarchy y las referencias a su nombre. Sin frameworks.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MENU="${ROOT_DIR}/omarchy/.config/omarchy/extensions/omarchy-menu.jsonc"

fail() { echo "FAIL: $*"; exit 1; }

menu="$(grep -v '^[[:space:]]*//' "${MENU}")"
grep -q '"appearance.rgb"' <<<"${menu}" || fail "falta la entrada appearance.rgb"
! grep -q '"style\.' <<<"${menu}" || fail "queda una clave style.* huérfana"
grep -q '"system.hw"' <<<"${menu}" || fail "falta la entrada system.hw"
grep -q '"label": "Work workspaces"' <<<"${menu}" || fail "falta la etiqueta Work workspaces"
grep -q 'omarchy-launch-terminal zsh -ic hw' <<<"${menu}" || fail "system.hw no abre hw en una terminal nueva"
! grep -q 'shortcut\|"key"' <<<"${menu}" || fail "system.hw no debe tener atajo"
node -e 'JSON.parse(require("fs").readFileSync(0,"utf8").replace(/^\s*\/\/.*$/gm,""))' <"${MENU}" || fail "JSONC inválido"

! grep -q 'Style' "${ROOT_DIR}/omarchy/.local/bin/rgb" || fail "rgb todavía dice Style"
! grep -q 'Style → RGB' "${ROOT_DIR}/docs/omarchy.md" || fail "docs/omarchy.md todavía dice Style → RGB"
grep -q 'branding reset' "${ROOT_DIR}/docs/omarchy.md" || fail "docs/omarchy.md no avisa de branding reset"

echo "ok"
