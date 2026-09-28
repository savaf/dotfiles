# ============================================================================
# AUTO-INSTALACIÓN DE HERRAMIENTAS (ble.sh, starship)
# ============================================================================
# Mismo patrón que zinit en zsh: en cada arranque de shell se hace un chequeo
# barato y, si falta algo, se instala una sola vez. bash-completion no vive
# aquí porque es un paquete del sistema (ver packages/*.txt), no algo con
# instalador propio.

_bde_ensure_blesh() {
  local dir="${XDG_DATA_HOME:-$HOME/.local/share}/blesh"
  [[ -r "${dir}/ble.sh" ]] && return 0
  command -v curl >/dev/null 2>&1 || return 0
  echo "[bash] instalando ble.sh (autosugerencias + syntax highlighting)…" >&2
  local tmp; tmp="$(mktemp -d)"
  if curl -fsSL -o "${tmp}/ble.tar.xz" \
      https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz 2>/dev/null \
    && tar -xJf "${tmp}/ble.tar.xz" -C "${tmp}" 2>/dev/null; then
    bash "${tmp}"/ble-nightly/ble.sh --install "${XDG_DATA_HOME:-$HOME/.local/share}" 2>/dev/null \
      || echo "[bash] fallo instalando ble.sh; sigue sin autosugerencias." >&2
  else
    echo "[bash] no se pudo descargar ble.sh; sigue sin autosugerencias." >&2
  fi
  rm -rf "${tmp}"
}

_bde_ensure_starship() {
  command -v starship >/dev/null 2>&1 && return 0
  command -v curl >/dev/null 2>&1 || return 0
  echo "[bash] instalando starship…" >&2
  curl -sS https://starship.rs/install.sh 2>/dev/null \
    | sh -s -- --yes --bin-dir "$HOME/.local/bin" >/dev/null 2>&1 \
    || echo "[bash] fallo instalando starship; prompt por defecto." >&2
}
