#!/usr/bin/env bash
set -euo pipefail

# Self-check para xkb_merge() de bootstrap.sh. Sin frameworks.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define solo la función pura sin ejecutar main().
xkb_merge() {
  local cur="$1"
  case "${cur}" in *caps:escape*) echo "${cur}"; return 0 ;; esac
  case "${cur}" in
    "@as []"|"[]"|"") echo "['caps:escape']" ;;
    *)                echo "${cur%]}, 'caps:escape']" ;;
  esac
}

# Verifica que la copia aquí coincide con la de bootstrap.sh (no drift).
grep -q "echo \"\${cur%]}, 'caps:escape']\"" "${SCRIPT_DIR}/bootstrap.sh" \
  || { echo "FAIL: xkb_merge desincronizado con bootstrap.sh"; exit 1; }

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
