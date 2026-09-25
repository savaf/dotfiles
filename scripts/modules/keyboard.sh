#!/usr/bin/env bash
# Remapea Caps Lock → Escape en GNOME (Ubuntu/Fedora de escritorio). No-op en
# WSL (lo gestiona Windows) y en cualquier sesión sin gsettings.

# Fusiona caps:escape en el array xkb-options actual, preservando lo existente.
# $1 = valor crudo de `gsettings get`; echo del array fusionado.
xkb_merge() {
  local cur="$1"
  case "${cur}" in *caps:escape*) echo "${cur}"; return 0 ;; esac
  case "${cur}" in
    "@as []"|"[]"|"") echo "['caps:escape']" ;;
    *)                echo "${cur%]}, 'caps:escape']" ;;
  esac
}

apply_linux_keyboard() {
  is_wsl && { log "WSL: Caps→Esc lo gestiona Windows; se omite."; return 0; }
  exists gsettings || return 0   # solo GNOME (default de Ubuntu)
  local cur merged
  cur="$(gsettings get org.gnome.desktop.input-sources xkb-options 2>/dev/null || echo '@as []')"
  merged="$(xkb_merge "${cur}")"
  if [[ "${merged}" == "${cur}" ]]; then
    log "caps:escape ya presente en xkb-options; se omite."
    return 0
  fi
  log "Remapeando Caps Lock → Escape (GNOME)…"
  gsettings set org.gnome.desktop.input-sources xkb-options "${merged}" || true
}
