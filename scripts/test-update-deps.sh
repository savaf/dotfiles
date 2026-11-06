#!/usr/bin/env bash
# Test de scripts/update-deps.sh. Sin red: DEPS_ROOT apunta a una copia temporal de los archivos
# reales que edita el script, y DEPS_STUBS sustituye solo las consultas (latest_*, head_commit,
# sha256_url, skill_tree_hash) leyendo respuestas de archivos en ${STUB_DIR}. Un archivo ausente
# equivale a "fuente caída". Si el script avisa "no encuentro…", una regex ya no casa con el
# archivo real (deriva) y el test falla.
set -uo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="${repo}/scripts/update-deps.sh"

fails=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }
check() { if "${@:2}"; then ok "$1"; else bad "$1"; fi; }

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

FILES=(
  mise/.config/mise/config.toml
  scripts/modules/node.sh
  scripts/modules/llama.sh
  scripts/install-packages.sh
  scripts/install-claude-skills.sh
  packages/global-node-packages.txt
  packages/claude-skills.txt
)

# Stubs: cada consulta lee un archivo de ${STUB_DIR}; sin archivo, falla.
cat > "${work}/stubs.sh" <<'STUBS'
key() { local k="${1//[\/#@]/_}"; printf '%s' "${k}"; }
latest_mise() { cat "${STUB_DIR}/mise-$(key "$1")" 2>/dev/null; }
latest_github_release() { cat "${STUB_DIR}/gh-$(key "$1")" 2>/dev/null; }
latest_llama_build() { cat "${STUB_DIR}/llama-build" 2>/dev/null; }
latest_npm() { cat "${STUB_DIR}/npm-$(key "$1")" 2>/dev/null; }
head_commit() { cat "${STUB_DIR}/head-$(key "$1")" 2>/dev/null; }
sha256_url() { cat "${STUB_DIR}/sha-$(basename "$1")" 2>/dev/null; }
skill_tree_hash() { cat "${STUB_DIR}/tree-$(key "$1")" 2>/dev/null; }
STUBS

stubkey() { local k="${1//[\/#@]/_}"; printf '%s' "${k}"; }
h64() { printf '%064d' 0 | tr '0' "$1"; }   # hash de 64 hex de relleno con el dígito $1

# setup: raíz nueva con copias de los archivos reales y stubs que devuelven la versión ACTUAL
# (nada que subir). Cada caso pisa solo lo que necesita.
setup() {
  rm -r -f "${work}/root" "${work}/stub"
  ROOT="${work}/root"; STUB_DIR="${work}/stub"; CHANGES="${work}/changes.md"
  mkdir -p "${STUB_DIR}"
  local f line
  for f in "${FILES[@]}"; do mkdir -p "${ROOT}/$(dirname "${f}")"; cp "${repo}/${f}" "${ROOT}/${f}"; done
  while IFS= read -r line; do
    if [[ "${line}" =~ ^([A-Za-z0-9_.:/-]+)[[:space:]]*=[[:space:]]*(\{[^}]*version[[:space:]]*=[[:space:]]*)?\"([^\"]+)\" ]]; then
      printf '%s\n' "${BASH_REMATCH[3]}" > "${STUB_DIR}/mise-$(stubkey "${BASH_REMATCH[1]}")"
    fi
  done < <(sed -n '/^\[tools\]/,/^\[[a-z]/p' "${ROOT}/mise/.config/mise/config.toml")
  grep -oE 'nvm-sh/nvm/v[0-9.]+/' "${ROOT}/scripts/modules/node.sh" | head -1 | cut -d/ -f3 > "${STUB_DIR}/gh-nvm-sh_nvm"
  grep -oE 'NF_VERSION="v[0-9.]+"' "${ROOT}/scripts/install-packages.sh" | head -1 | cut -d'"' -f2 > "${STUB_DIR}/gh-ryanoasis_nerd-fonts"
  grep -oE 'LLAMA_CPP_VERSION="b[0-9]+"' "${ROOT}/scripts/modules/llama.sh" | cut -d'"' -f2 > "${STUB_DIR}/llama-build"
  grep -oE 'skills@[0-9][0-9.]*' "${ROOT}/scripts/install-claude-skills.sh" | head -1 | cut -d@ -f2 > "${STUB_DIR}/npm-skills"
  grep -oE '@karpeleslab/teamclaude@[0-9.]+' "${ROOT}/packages/global-node-packages.txt" | cut -d@ -f3 > "${STUB_DIR}/npm-_karpeleslab_teamclaude"
  while IFS= read -r line; do
    if [[ "${line}" =~ ^([^#[:space:]]+/[^#[:space:]]+)#([0-9a-f]{40}) ]]; then
      printf '%s\n' "${BASH_REMATCH[2]}" > "${STUB_DIR}/head-$(stubkey "${BASH_REMATCH[1]}")"
    fi
  done < "${ROOT}/packages/claude-skills.txt"
}

# run <modo>: corre el script contra ${ROOT}; deja stderr en ${work}/err y el código en ${rc}.
run() {
  rc=0
  DEPS_ROOT="${ROOT}" DEPS_STUBS="${work}/stubs.sh" STUB_DIR="${STUB_DIR}" CHANGES_FILE="${CHANGES}" \
    bash "${script}" "$@" > /dev/null 2> "${work}/err" || rc=$?
}
unchanged() { cmp -s "${repo}/$1" "${ROOT}/$1"; }
all_unchanged() { local f; for f in "${FILES[@]}"; do unchanged "${f}" || return 1; done; }
changes_has() { grep -qF -- "$1" "${CHANGES}"; }
no_drift() { ! grep -q 'AVISO: no encuentro' "${work}/err"; }
mise_cfg="mise/.config/mise/config.toml"

# --- Sin cambios -----------------------------------------------------------------------------
setup; run tools
check "sin cambios: tools sale 0" test "${rc}" -eq 0
check "sin cambios: CHANGES_FILE vacío" test ! -s "${CHANGES}"
check "sin cambios: ningún archivo tocado" all_unchanged
check "sin cambios: sin deriva de regex" no_drift
setup; run skills
check "sin cambios: skills deja CHANGES_FILE vacío" test ! -s "${CHANGES}"
check "sin cambios: skills sin deriva de regex" no_drift

# --- Sube cada pin ---------------------------------------------------------------------------
setup; echo 99.0.0 > "${STUB_DIR}/mise-neovim"; run tools
check "mise: sube neovim" grep -q '^neovim = "99.0.0"' "${ROOT}/${mise_cfg}"
check "mise: el resto de líneas no cambia" test "$(diff "${repo}/${mise_cfg}" "${ROOT}/${mise_cfg}" | grep -c '^>')" -eq 1
check "mise: queda en CHANGES_FILE" changes_has 'neovim'
check "mise: sin deriva de regex" no_drift

setup; echo 99.1.0 > "${STUB_DIR}/mise-eza"; run tools
check "mise: sube versión dentro de tabla inline (eza)" grep -q 'eza = { version = "99.1.0"' "${ROOT}/${mise_cfg}"

setup; echo v99.0.0 > "${STUB_DIR}/gh-nvm-sh_nvm"; run tools
check "nvm: sube la URL de install.sh" grep -q 'nvm-sh/nvm/v99.0.0/install.sh' "${ROOT}/scripts/modules/node.sh"
check "nvm: sin deriva de regex" no_drift

setup; echo v99.0.0 > "${STUB_DIR}/gh-ryanoasis_nerd-fonts"; run tools
check "Nerd Font: sube NF_VERSION" grep -q 'NF_VERSION="v99.0.0"' "${ROOT}/scripts/install-packages.sh"

setup; echo 99.0.0 > "${STUB_DIR}/npm-_karpeleslab_teamclaude"; run tools
check "npm: sube el paquete fijado" grep -q '@karpeleslab/teamclaude@99.0.0' "${ROOT}/packages/global-node-packages.txt"

setup; echo 99.0.0 > "${STUB_DIR}/npm-skills"; run tools
check "CLI skills: sube SKILLS_CLI" grep -q 'SKILLS_CLI="skills@99.0.0"' "${ROOT}/scripts/install-claude-skills.sh"

# llama.cpp: tag + 2 sha256
setup
echo b99999 > "${STUB_DIR}/llama-build"
h64 a > "${STUB_DIR}/sha-llama-b99999-bin-ubuntu-cuda-12.8-x64.tar.gz"
h64 b > "${STUB_DIR}/sha-cudart-llama-b99999-bin-ubuntu-cuda-12.8-x64.tar.gz"
run tools
check "llama: sube el tag" grep -q 'LLAMA_CPP_VERSION="b99999"' "${ROOT}/scripts/modules/llama.sh"
check "llama: nuevo sha256 de llama" grep -q "\[llama\]=$(h64 a)" "${ROOT}/scripts/modules/llama.sh"
check "llama: nuevo sha256 de cudart-llama" grep -q "\[cudart-llama\]=$(h64 b)" "${ROOT}/scripts/modules/llama.sh"
check "llama: sin deriva de regex" no_drift

# skills: línea sin tarball y línea con tarball (+ hash)
new1="$(printf 'f%.0s' {1..40})"; new2="$(printf 'e%.0s' {1..40})"
setup
echo "${new1}" > "${STUB_DIR}/head-mattpocock_skills"
echo "${new2}" > "${STUB_DIR}/head-pbakaus_impeccable"
h64 c > "${STUB_DIR}/tree-pbakaus_impeccable"
run skills
check "skills: sube el commit de una línea simple" grep -q "^mattpocock/skills#${new1}" "${ROOT}/packages/claude-skills.txt"
check "skills: sube commit y hash de una línea con tarball" grep -q "^pbakaus/impeccable#${new2} impeccable .claude/skills/impeccable $(h64 c)" "${ROOT}/packages/claude-skills.txt"
check "skills: el resto de líneas no cambia" test "$(diff "${repo}/packages/claude-skills.txt" "${ROOT}/packages/claude-skills.txt" | grep -c '^>')" -eq 2
check "skills: lista de auditoría en CHANGES_FILE" changes_has '- [ ] `mattpocock/skills`'

# --- No baja ni toca si menor; ignora prereleases ---------------------------------------------
setup
echo 0.0.1 > "${STUB_DIR}/mise-neovim"
echo v0.0.1 > "${STUB_DIR}/gh-nvm-sh_nvm"
echo v0.0.1 > "${STUB_DIR}/gh-ryanoasis_nerd-fonts"
echo b1 > "${STUB_DIR}/llama-build"
echo 0.0.1 > "${STUB_DIR}/npm-skills"
run tools
check "menor: no baja nada" test ! -s "${CHANGES}"
check "menor: ningún archivo tocado" all_unchanged

setup
echo 99.0.0-rc1 > "${STUB_DIR}/mise-neovim"
echo 99.0.0-beta.1 > "${STUB_DIR}/npm-skills"
run tools
check "prerelease: se ignora" test ! -s "${CHANGES}"
check "prerelease: ningún archivo tocado" all_unchanged

# --- Fuente caída: avisa, deja el archivo intacto y sigue --------------------------------------
setup
rm "${STUB_DIR}/mise-neovim" "${STUB_DIR}/gh-nvm-sh_nvm"
echo 99.0.0 > "${STUB_DIR}/mise-lazygit"
run tools
check "fuente caída: sale 0" test "${rc}" -eq 0
check "fuente caída: nvm intacto" unchanged scripts/modules/node.sh
check "fuente caída: sigue con las demás (lazygit)" grep -q '^lazygit = "99.0.0"' "${ROOT}/${mise_cfg}"
check "fuente caída: neovim intacto" grep -qxF "$(grep '^neovim' "${repo}/${mise_cfg}")" "${ROOT}/${mise_cfg}"
check "fuente caída: avisa en stderr" grep -q 'AVISO' "${work}/err"
check "fuente caída: sección Avisos en CHANGES_FILE" changes_has '## Avisos'
check "fuente caída: el aviso nombra la fuente" changes_has 'nvm-sh/nvm'

# llama: si falla un sha256, no toca nada
setup
echo b99999 > "${STUB_DIR}/llama-build"
h64 a > "${STUB_DIR}/sha-llama-b99999-bin-ubuntu-cuda-12.8-x64.tar.gz"   # falta el de cudart
run tools
check "llama: un sha256 caído no toca nada" unchanged scripts/modules/llama.sh
check "llama: avisa" changes_has 'llama.cpp'

# skills: si falla el hash, no toca la línea (y sigue con otras)
setup
echo "${new1}" > "${STUB_DIR}/head-mattpocock_skills"
echo "${new2}" > "${STUB_DIR}/head-pbakaus_impeccable"      # sin tree-… → hash caído
run skills
check "skills: sin hash no toca la línea con tarball" grep -q '^pbakaus/impeccable#414603bf' "${ROOT}/packages/claude-skills.txt"
check "skills: sigue con las demás" grep -q "^mattpocock/skills#${new1}" "${ROOT}/packages/claude-skills.txt"
check "skills: avisa del hash" changes_has 'pbakaus/impeccable'
check "skills: sección Avisos" changes_has '## Avisos'

# --- Marca ⚠ major ----------------------------------------------------------------------------
setup; echo 99.0.0 > "${STUB_DIR}/mise-neovim"; echo 0.99.0 > "${STUB_DIR}/mise-lazygit"; run tools
check "major: marca el salto de componente mayor" grep -q 'neovim.*⚠ \*\*major\*\*' "${CHANGES}"
check "major: no marca el cambio menor" bash -c "! grep 'lazygit' '${CHANGES}' | grep -q major"

# --- Modo inválido ----------------------------------------------------------------------------
setup; run nope
check "modo inválido sale con 2" test "${rc}" -eq 2
setup; run
check "sin modo sale con 2" test "${rc}" -eq 2

echo
if [[ ${fails} -eq 0 ]]; then echo "update-deps: todo ok"; else echo "update-deps: ${fails} fallo(s)"; exit 1; fi
