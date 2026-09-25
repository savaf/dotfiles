#!/usr/bin/env bash
# Genera el locale en_US.UTF-8 en Ubuntu/Debian si hace falta. Idempotente.

ensure_locale() {
  case "${OS}" in ubuntu|debian) ;; *) return 0 ;; esac
  exists locale-gen || return 0
  # Idempotente: si ya está generado, no hace nada.
  if locale -a 2>/dev/null | grep -qiE '^en_US\.utf-?8$'; then
    log "Locale en_US.UTF-8 ya presente; se omite."
    return 0
  fi
  log "Generando locale en_US.UTF-8…"
  sudo locale-gen en_US.UTF-8
  sudo update-locale LANG=en_US.UTF-8
}
