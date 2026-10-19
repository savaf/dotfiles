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

# --- Herramientas CLI gestionadas por mise (config global como paquete Stow) ---
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MISE_CONFIG="${ROOT_DIR}/mise/.config/mise/config.toml"
# binario:herramienta:paquetes-del-sistema (nombres equivalentes en apt/dnf/pacman/brew)
MISE_TOOLS=(
  nvim:neovim:neovim
  lazygit:lazygit:lazygit
  lazydocker:lazydocker:lazydocker
  dua:dua:dua,dua-cli
  starship:starship:starship
)

[[ -f "${MISE_CONFIG}" ]] || { echo "FAIL: falta ${MISE_CONFIG}"; exit 1; }
grep -Eq '^STOW_PACKAGES=\(.*\bmise\b' "${SCRIPT_DIR}/modules/stow.sh" \
  || { echo "FAIL: 'mise' no está en STOW_PACKAGES"; exit 1; }
for entry in "${MISE_TOOLS[@]}"; do
  IFS=: read -r _ tool _ <<<"${entry}"
  grep -Eq "^\"?${tool}\"? *=" "${MISE_CONFIG}" \
    || { echo "FAIL: ${tool} no declarado en la config de mise"; exit 1; }
done
echo "OK: config de mise"

# Doble origen: lo que mise instala no puede seguir en un manifiesto del sistema.
for entry in "${MISE_TOOLS[@]}"; do
  IFS=: read -r _ tool pkgs <<<"${entry}"
  for manifest in "${ROOT_DIR}"/packages/{apt-cli,dnf-cli,pacman-cli,brew-cli}.txt; do
    for pkg in ${pkgs//,/ }; do
      sed 's/#.*//; s/[[:space:]]*$//' "${manifest}" | grep -Fxq "${pkg}" \
        && { echo "FAIL: ${tool} (${pkg}) está en mise y en ${manifest##*/}"; exit 1; }
    done
  done
done
echo "OK: sin doble origen mise/sistema"

# Instala lo declarado y comprueba que cada binario resuelve desde un sh sin
# activación (como un popup de tmux o un launcher): solo vale el PATH de shims, y
# su --version debe contener la versión fijada en la config.
if command -v mise >/dev/null 2>&1; then
  export MISE_GLOBAL_CONFIG_FILE="${MISE_CONFIG}"
  for _ in 1 2; do  # la segunda pasada comprueba la idempotencia
    out="$(mise install -y 2>&1)" || { echo "FAIL: mise install"; echo "${out}"; exit 1; }
  done
  shims="${MISE_DATA_DIR:-${HOME}/.local/share/mise}/shims"
  for entry in "${MISE_TOOLS[@]}"; do
    IFS=: read -r bin tool _ <<<"${entry}"
    want="$(sed -n "s/^${tool} *= *\"\(.*\)\"/\1/p" "${MISE_CONFIG}")"
    got="$(env -i HOME="${HOME}" MISE_GLOBAL_CONFIG_FILE="${MISE_CONFIG}" PATH="${shims}:/usr/bin:/bin" \
      sh -c "${bin} --version" 2>&1 | head -3)" || true
    [[ -n "${want}" && "${got}" == *"${want}"* ]] \
      || { echo "FAIL: ${bin} --version no contiene '${want}': ${got}"; exit 1; }
  done
  echo "OK: herramientas resuelven sin activación en la versión fijada"
else
  echo "SKIP: mise no instalado; no se comprueba la instalación"
fi
