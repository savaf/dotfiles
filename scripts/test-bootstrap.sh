#!/usr/bin/env bash
set -euo pipefail

# Self-check para xkb_merge() de scripts/modules/keyboard.sh. Sin frameworks.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=modules/keyboard.sh
source "${SCRIPT_DIR}/modules/keyboard.sh"

check() {  # $1 entrada  $2 esperado
  local got; got="$(xkb_merge "$1")"
  [[ "${got}" == "$2" ]] || { echo "FAIL: '$1' → '${got}' (esperado '$2')"; exit 1; }
}

check "@as []"             "['caps:escape']"
check "[]"                 "['caps:escape']"
check "['compose:ralt']"   "['compose:ralt', 'caps:escape']"
check "['caps:escape']"    "['caps:escape']"                       # idempotente
check "['a', 'caps:escape']" "['a', 'caps:escape']"                # ya presente

echo "OK: xkb_merge"
