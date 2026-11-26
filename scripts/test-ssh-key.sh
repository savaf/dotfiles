#!/usr/bin/env bash
set -euo pipefail

# Self-check de link_ssh_key() (scripts/modules/stow.sh) y de allowed_signers.
# HOME temporal y `hostname` stub: no toca el $HOME real, la red ni el agente.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=modules/stow.sh
source "${SCRIPT_DIR}/modules/stow.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
ROOT_DIR="${TMP}/repo"
HOME="${TMP}/home"
mkdir -p "${ROOT_DIR}/ssh/.ssh" "${HOME}/.ssh"
echo "ssh-ed25519 AAAAfake" >"${HOME}/.ssh/box.pub"
hostname() { echo box; }

fail() { echo "FAIL: $*"; exit 1; }
LINK="${HOME}/.ssh/github.pub"

# 1. enlace correcto
link_ssh_key >/dev/null
[[ -L "${LINK}" && "$(readlink "${LINK}")" == "${HOME}/.ssh/box.pub" ]] || fail "github.pub no apunta a box.pub"
# 2. idempotente
link_ssh_key >/dev/null
[[ "$(readlink "${LINK}")" == "${HOME}/.ssh/box.pub" ]] || fail "rerun cambió el enlace"
# 2b. hostname con mayúsculas (WSL/macOS) también enlaza
rm "${LINK}"
hostname() { echo BOX; }
link_ssh_key >/dev/null
[[ "$(readlink "${LINK}")" == "${HOME}/.ssh/box.pub" ]] || fail "hostname en mayúsculas no enlaza"
# 3. falta <hostname>.pub: avisa y no crea nada
rm "${LINK}"
hostname() { echo sinllave; }
out="$(link_ssh_key)"
[[ "${out}" == *"sinllave.pub"* ]] || fail "no avisa de la .pub faltante: ${out}"
[[ ! -e "${LINK}" && ! -L "${LINK}" ]] || fail "creó github.pub sin .pub"
# 4. no pisa un archivo real
hostname() { echo box; }
echo "mia" >"${LINK}"
out="$(link_ssh_key)"
[[ ! -L "${LINK}" && "$(<"${LINK}")" == "mia" ]] || fail "pisó un archivo real"
[[ "${out}" == *"github.pub"* ]] || fail "no avisa del archivo real: ${out}"
echo "OK: link_ssh_key"

# 4b. zsh y bash reponen el enlace si falta o está roto, y no pisan un archivo real
for sh in zsh bash; do
  if ! command -v "${sh}" >/dev/null 2>&1; then
    echo "AVISO: sin ${sh}; no se prueba la reposición de github.pub"
    continue
  fi
  case "${sh}" in
    zsh)  flags=(-f); rc="${REPO}/zsh/.config/zsh/integrations.zsh"; var=HOST ;;
    bash) flags=(--norc --noprofile); rc="${REPO}/bash/.config/bash/integrations.sh"; var=HOSTNAME ;;
  esac
  heal() { HOME="${HOME}" "${sh}" "${flags[@]}" -c "${var}=Box.local; source \"\$1\"" _ "${rc}" >/dev/null 2>&1 || true; }
  rm -f "${LINK}"; heal
  [[ "$(readlink "${LINK}")" == "${HOME}/.ssh/box.pub" ]] || fail "${sh} no repuso github.pub"
  ln -sfn "${HOME}/.ssh/vieja.pub" "${LINK}"; heal
  [[ "$(readlink "${LINK}")" == "${HOME}/.ssh/box.pub" ]] || fail "${sh} no reparó el enlace roto"
  rm "${LINK}"; echo "mia" >"${LINK}"; heal
  [[ ! -L "${LINK}" && "$(<"${LINK}")" == "mia" ]] || fail "${sh} pisó un archivo real"
  echo "OK: ${sh} repone github.pub"
done

# 5. allowed_signers contiene la clave de cada .pub versionado
signers="${REPO}/ssh/.ssh/allowed_signers"
for pub in "${REPO}"/ssh/.ssh/*.pub; do
  read -r type key _ <"${pub}"
  grep -Fq "${type} ${key}" "${signers}" \
    || fail "${pub##*/} no está en allowed_signers: añade su línea"
done
echo "OK: allowed_signers cubre cada .pub"
